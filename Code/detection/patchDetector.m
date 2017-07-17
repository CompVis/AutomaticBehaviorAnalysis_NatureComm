function patchDetector(fl,cellSize,positionPrior,vis_b)
%patchDetector -  This function detects the paw in every frame using
%                 Max-projected randomized Exemplar Classifiers and saves
%                 the first embedding (scores of 120 exemplar classifiers)
%
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames, fl.det)
%   cellSize        - size of the cells for creating the HOG descriptors
%   positionPrior   - sets the region where the paw is expected
%   vis_b           - 1 for plotting the frames superimposed by the score
%                     Map,0 otherwise
%
% Subfunctions: nms: Non-max-supression
% MAT-files required: posPatches*.mat: contain the information of the
%                                      already trained max-projected randomized
%                                      exemplar classifiers; trained by
%                                      using the library liblinear
%                                      (https://www.csie.ntu.edu.tw/~cjlin/liblinear/)
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017
    
    if nargin<3
        vis_b = 0;
    end
    if ~exist(fl.det,'dir')
        mkdir(fl.det);
    end
    
    %load all exemplar classifiers
    folder_classifiers = 'detection/exemplars/';
    files = dir([folder_classifiers,'/posPatches*.mat']);
    for i = 1:numel(files)
        load([folder_classifiers, files(i).name]);
        posPatches(i) = posPatches2;
        clear posPatches2
    end
    posPatches2 = posPatches;


    folder_hog = [fl.pre,'/hog'];
    
    %as in HOG: group several detections
    nr_files = numel(dir([folder_hog,'/*.mat']));
    
    %for loop over blocks
    rem = 0;
    for n = 1:nr_files
        for r=1:rem;fprintf('\b');end;
        fprintf('%i/%i',n,nr_files);
        rem = numel(num2str(n))+numel(num2str(nr_files))+1;

        det_name = [fl.det,sprintf('/%03i_detections.mat',n)];
        traj_name = [fl.det,sprintf('/%03i_trajectory.mat',n)];
        
        if exist(det_name,'file') && exist(traj_name,'file');continue;end

        %load hog of the nth block
        l_hog = load([folder_hog,sprintf('/%03i_hog.mat',n)]);
        frame_nr = [l_hog.patch(:).frame_nr];
        
        %load the frames if vis_b is true
        %load the change of the grid because of sugar alignments
        load([fl.pre,'/alignedGrid.mat']);
        if vis_b
            for j=1:numel(frame_nr)
                patch(j).cdata = imread(sprintf('%s/%06d.jpg',fl.frames,frame_nr(j)));
                patch(j).cdata = patch(j).cdata(newStart(2):end,newStart(1):end,:);
            end
        end


        scoreMap_all = cell(numel(l_hog.patch),1);
        scoreAcc_all = cell(numel(l_hog.patch),1);
        %for loop over frames which belong to grasp n
        for i = 1:numel(frame_nr)
            if vis_b;im = patch(i).cdata;end;
            mask = im2single(l_hog.patch(i).mask);
            hog = l_hog.patch(i).hog;
            %set all regions where no paw is expected to zero
            mask(~imresize(positionPrior,[size(mask,1),size(mask,2)])) = 0;
            if ~isempty(hog) 
                clear Scores
                %for-loop over all classifiers
                parfor j = 1:numel(posPatches2)
                    %set some parameters
                    %width of bounding box in hog space
                    svmWidth = size(posPatches2(j).w, 2);
                    %height of bounding box in hog space
                    svmHeight = size(posPatches2(j).w, 1);
                    %only hog values above svmThresh are necessary
                    svmThresh = posPatches2(j).svmThresh;
                    maskThresh = posPatches2(j).maskThresh;
                    %coefficients of logistic regression result
                    logitCoef = posPatches2(j).logitCoef;
                    %threshold hog
                    hog2 = hog .* (hog >= svmThresh);

                    %apply jth classifier
                    Chog = convn(hog2, posPatches2(j).w, 'valid') + posPatches2(j).b;


                    %get score of jth classifier (after training the
                    %exemplar SVM logistic regression was applied to change
                    %the range of the SVM to [0,1]
                    logitScore = mnrval(logitCoef, Chog(:));
                    logitScore = reshape(logitScore(:,2), size(Chog));

                    %take only the location where the mask indicates
                    %movement, if no movement, set score to zero
                    mask_conv = double(posPatches2(j).mask);
                    Cmask = conv2(mask, mask_conv, 'valid');
                    Cmask = Cmask / (sum(sum(mask_conv==1))); 
                    logitScore(Cmask < maskThresh) = 0;

                    %apply non-max suppression
                    [X, Y] = meshgrid(1:size(logitScore,2), ...
                        1:size(logitScore,1));
                    boxes = [X(:), Y(:), X(:)+svmWidth-1, ...
                        Y(:)+svmHeight-1, logitScore(:)];
                    top = nms(boxes, 0.5);

                    scores = zeros(size(hog,1), size(hog,2));

                    %save scores of the maxima gained in non-max
                    %suppression
                    for k = 1:3
                        scores(top(k,2)+floor(svmHeight/2), ...
                            top(k,1)+floor(svmWidth/2)) = top(k,5);
                    end

                    %apply gaussian filter
                    h = fspecial('gaussian', [7 7], 2);
                    Scores{j} = conv2(scores, h / h(4,4), 'same');
                end


                %average the scores of the top scoring k=10 classifiers
                scoreAcc = zeros(size(hog,1), size(hog,2), numel(posPatches2));
                for j = 1:numel(Scores)
                    scoreAcc(:,:,j) = Scores{j};
                end
                scoreAcc_all{i} = scoreAcc; %for embedding
                kNN = 10;
                scoreMap  = sort(scoreAcc, 3, 'descend');
                scoreMap = mean(scoreMap(:,:,1:kNN) , 3);
                scoreMap_all{i} = scoreMap; %for embedding

                %visualization
                if vis_b
                    I = imresize(scoreMap,cellSize,'nearest');
                    numCellsX = floor(size(im,2)/cellSize);
                    numCellsY = floor(size(im,1)/cellSize);
                    im2 = im(1:numCellsY*cellSize,1:numCellsX*cellSize,:);
                    I = im2double(im2) + im2double(label2rgb(im2uint8(I),'jet','k'));
                    imshow(I);
                    title(num2str(max(scoreMap_all{i}(:))));
                    pause(0.1);
                end

                %save detection result in detections
                detections(i).scoreMap = scoreMap;
            else
                detections(i).scoreMap = [];
                detections(i).cdata = [];
            end
        end

        save([fl.det,sprintf('/%03i_detections',n)],'detections','-v7.3');


        % Embedding
        nr_max = 8;

        track = zeros(length(scoreMap_all),3,nr_max);

        %get the (x,y) coordinates and the score of the local maxima
        for f=1:length(scoreMap_all)
            scoreMap_f = scoreMap_all{f};
            if ~isempty(scoreMap_f)

                %apply nms to get the 8 best local maxima
                [X, Y] = meshgrid(1:size(scoreMap_f,2), ...
                        1:size(scoreMap_f,1));
                boxes = [X(:), Y(:), X(:)+15-1, ...
                    Y(:)+10-1, scoreMap_f(:)];
                %apply non-max suppression
                top = nms(boxes, 0.5);

                %save the coordinates of the local maxima in track
                for t=1:nr_max
                    track(f,1,t) = top(t,1);%+floor(3/2);
                    track(f,2,t) = top(t,2);%+floor(3/2);
                    track(f,3,t) = top(t,5);
%                     plot(track(f,1,t)*10,track(f,2,t)*10,'*k','LineWidth',4);
                end
            else
                track(f,:,:) = -ones(1,3,nr_max);
            end

        end
        trajectory.track = track;
        trajectory.scores = [];
        for f = 1:numel(scoreAcc_all) 
            if track(f,1,1)~=-1
                for c = 1:numel(posPatches)
                    for t=1:nr_max

                        I1 = max(round(track(f,2,t) - 1), 1);
                        I2 = min(round(track(f,2,t) + 1), size(scoreAcc_all{f},1));

                        J1 = max(round(track(f,1,t) - 1), 1);
                        J2 = min(round(track(f,1,t) + 1), size(scoreAcc_all{f},2));

                        tmpMap = scoreAcc_all{f}(I1:I2, J1:J2, c);

                        trajectory.scores(f,c,t) = max(tmpMap(:));

                    end
                end
             else
                trajectory.scores(f,:,:) = -ones(1,numel(posPatches),nr_max);
            end
        end
        save([fl.det,sprintf('/%03i_trajectory',n)],'trajectory','-v7.3');
    end
    close(gcf);
end
