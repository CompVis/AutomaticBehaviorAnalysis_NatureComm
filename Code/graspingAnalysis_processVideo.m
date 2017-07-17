function graspingAnalysis_processVideo(vid_path,wa_path,cplex_path,createVideo_b)
%graspingAnalysis_processVideo  - This is the main function of the provided
%                                 Software for detecting the paw and
%                                 generating the posture and sequence
%                                 embedding of a specific video.
%
% Inputs:
%   vid_path            - path of the video which should get processed
%   wa_path             - path of the working space (e.g. ./)
%   cplex_path          - path of the cplex toolkit (if sequence matching
%                         should be executed)
%   createVideo_b       - 1 if a video with superimposed bounding boxes of
%                         the detections/grasps should be created, 0
%                         otherwise
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    if nargin<4
        createVideo_b = 0;
    end
    cd(wa_path);
    addpath('toolboxes');
    addpath('preprocessing');
%% set some parameters
    %for the foreground map
    resize_value = 0.4;
    thresh_foregr = 0.15;
    block_size = 100;
    nr_perFile = 200;
    %for computing the HOG feature
    cellSize = 10;
    %size of the bounding box around the detection
    bbox_size = 100;
    
    k = strfind(vid_path,'/');
    vid_file = vid_path(k(end)+1:end);
    
%% load the video
    fprintf('Load the video...');
    addpath(genpath('toolboxes/mmread'));
    video = mmread(vid_path);
    nr_frames = length(video.frames);
    fprintf('Done \n');
    
%% extract the frames (it is faster to load the frames as jpgs as opposed to always loading the whole video)
    
    %folder to save the frames of the video
    fl.frames = ['video/frames/',vid_file(1:end-4)];
    if ~exist(fl.frames,'file')
        mkdir(fl.frames);
    end
    
    %check if it is necessary to extract the frames or if all frames of
    %this video are already extracted
    framesExtracted = dir([fl.frames,'/*.jpg']);
    if length(framesExtracted)~=length(video.frames)
        fprintf('Extract the frames...');
        %save the frames
        rem = 0;
        for i=1:length(video.frames)
            if mod(i,200)==0
                for r=1:rem;fprintf('\b');end;
                fprintf('%i/%i',i,length(video.frames));
                rem = numel(num2str(i))+numel(num2str(length(video.frames)))+1;
            end
            f = video.frames(i).cdata;
            imwrite(f,[fl.frames,sprintf('/%06d.jpg',i)],...
                        'quality',80);
        end
        for r=1:rem;fprintf('\b');end;
        fprintf('%i/%i',length(video.frames),length(video.frames));
    end

%% Do preprocessing
    fl.pre = ['preprocessing/',vid_file(1:end-4)];
    if ~exist(fl.pre,'file')
        mkdir(fl.pre);
    end
    
    %% 1. Shelf location
    fprintf('Get the shelf position...');
    shelf_file = [fl.pre,'/shelf.mat'];
    [~,rightLine] = shelf_detection(nr_frames,fl.frames,shelf_file,0);
    fprintf('Done \n');
    
    %% 2. Sugar location
    %start the area of interest where the sugar should be detected with the
    %previous shelf detection
    fprintf('Get sugar position...');
    ROI = [rightLine,730,150,315];
    detect_sugar_position(fl,nr_frames,ROI);
    fprintf('Done \n');
    
    %% 3. Mean Frame
    getMeanFrame(fl,nr_frames);

    %% 4. Get foreground using robust PCA
    disp('Compute foreground map with rpca...');
    addpath(genpath('toolboxes/inexact_alm_rpca'));
    %save the parameters necessary for computing the foreground in one
    %struct
    rpca_params.block_size = block_size;
    rpca_params.nr_perFile = nr_perFile;
    rpca_params.resize_value = resize_value;
    rpca_params.nr_frames = nr_frames;
    %compute foreground
    getForeground(fl,rpca_params);
    
    %% 5. Get HOG descriptor for every frame
    disp('Compute HOG descriptors...');
    addpath(genpath('toolboxes/vlfeat-0.9.19'));
    
    %save the parameters necessary for computing the hog descriptors in one
    %struct
    hog_params = rpca_params;
    hog_params.cellSize = cellSize;
    hog_params.thresh_foregr = thresh_foregr;
    %compute hog
    fprintf('Get HOG descriptor...');
    getHog(fl,hog_params);
    fprintf('Done \n');
    
%% Detection of the paw
    
    %get position Prior (restricts the area for detections)
    load([fl.pre,'/positionPrior.mat']);
    
    %detect
    addpath('detection');
%     addpath(genpath('toolboxes/liblinear-1.96'));
    fl.det = ['detection/',vid_file(1:end-4)];
    fprintf('Detect...');
    patchDetector(fl,cellSize,positionPrior_b,0);
   
    
    %in 'patchDetector' several detection candidates where saved/computed,
    %now: find the best candidate in getMax
    max_params = hog_params;
    max_params.bbox_size = bbox_size;
    getMax(fl,max_params,positionPrior_b);
    
    %cut the whole Video in individual grasps
    addpath(genpath('toolboxes/extrema'));
    fprintf('getGrasps...');
    getGrasps(fl,cellSize,0);
    fprintf('Done \n');
    
%% Create the final video
    %show the grasps and detections by plotting the detections on top of
    %the video frames
    if createVideo_b
        video_params = max_params;
        createVideo(fl,video_params,'grasp');
    end
    
%% collect all grasps
    fprintf('Collect all grasps...');
    collectGrasps(fl);

    %if desired the next function can plot the nearest neighbors of
    %randomly chosen detections (click on the figure for next plot)
    plotNearestNeighbor(fl);

    %if desired the next function can plot the embedding of randomly chosen
    %detections after applying a dimensionality reduction method
    plotPatchesInTSNESpace(fl);

%% Create sequence embedding (2nd embedding)
    if ~isempty(cplex_path)
        addpath('sequence_embedding');
        
        fprintf('Create sequence embedding: \n');
        fl.seqMatch = ['sequence_embedding/',vid_file(1:end-4)];
        if ~exist(fl.seqMatch,'file')
            mkdir(fl.seqMatch);
        end

        fprintf('Get Sequence embedding...');
        %for sequence matching we need the library cplex of IBM
        addpath(genpath(cplex_path));
        matchAllSeqs(fl);
    end
