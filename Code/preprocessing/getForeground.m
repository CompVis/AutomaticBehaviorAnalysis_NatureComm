function getForeground(fl,params)
%getForeground -  This function uses robust PCA to compute the 
%                 background/foreground map for every frame in the video
%
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames)
%   params          - structure of required parameters
%
% Subfunctions: inexact_alm_rpca: code for applying robust PCA
%               (http://perception.csl.illinois.edu/matrix-rank/sample_code.html)
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    nr_frames = params.nr_frames;
    block_size = params.block_size;
    out_folder = [fl.pre,'/rpca'];
    %define the folder where the rpca results are saved
    if ~exist(out_folder,'dir')
        mkdir(out_folder);
    end

    img = [];
    %load all images
    fprintf('getForeground: get all images...');
    rem = 0;
    for i=1:nr_frames
        if mod(i,100)==0
            for r=1:rem;fprintf('\b');end;
            fprintf('%i/%i',i,nr_frames);
            rem = numel(num2str(i))+numel(num2str(nr_frames))+1;
        end
        patch = imread([sprintf('%s/%06d.jpg',fl.frames, i)]);
        img(i).cdata = imresize(patch, params.resize_value);
        img(i).frame_nr = i;
    end
    for r=1:rem;fprintf('\b');end;
    fprintf('%i/%i',nr_frames,nr_frames);
    fprintf('\n');

    %choose a random order of img to ensure that no consecutive
    %frames are in one block -> better separation between
    %background and foreground
    P = randperm(numel(img));  
    %run rpca several times for different blocks
    total_blocks = floor(numel(img)/block_size);
    %apply rpca
    rpca_res = [];
    fprintf('getForeground: apply rpca...');
    for i = 1:total_blocks
        if i==1;rem=0;end
        for r=1:rem;fprintf('\b');end;
        fprintf('%i/%i',i,total_blocks);
        rem = numel(num2str(i))+numel(num2str(total_blocks))+1;

        %D contains the images of the ith block
        D = [];
        for j = 1:block_size
            I = im2double(img(P((i-1)*block_size+j)).cdata);
            D(:,j) = reshape(rgb2gray(I),[],1);
        end

        %rpca function, output: E is the foreground map of all
        %images of block i
        [~, E] = inexact_alm_rpca(D, 0.6/sqrt(size(D,1)));

        %save the foreground result in rpca_res
        for j = 1:block_size
            I = reshape(E(:,j), [size(img(1).cdata,1) size(img(1).cdata,2)]);
            rpca_res(P((i-1)*block_size+j)).cdata = I;
            rpca_res(P((i-1)*block_size+j)).colormap = [];
            rpca_res(P((i-1)*block_size+j)).frame_nr = img(P((i-1)*block_size+j)).frame_nr;
        end
    end
    fprintf('/n');

    %compute the foreground of the remaining imgs which are not enough to form
    %another block
    disp('getForeground: apply rpca: remainings');
    %for the last foreground block, take some more
    D = [];
    nr_left_frames = nr_frames-(total_blocks*block_size);
    additional_frames = block_size-nr_left_frames;
    for j = 1:block_size
        I = im2double(img(P(total_blocks*block_size-...
            additional_frames+1+(j-1))).cdata);
        D(:,j) = reshape(rgb2gray(I),[],1);
    end
    [~, E] = inexact_alm_rpca(D, 0.6/sqrt(size(D,1)));
    for j=1:nr_left_frames%additional_frames+1:block_size
        I = reshape(E(:,additional_frames+j), [size(img(1).cdata,1) size(img(1).cdata,2)]);
        rpca_res(P(total_blocks*block_size+j)).cdata = I;
        rpca_res(P(total_blocks*block_size+j)).colormap = [];
        rpca_res(P(total_blocks*block_size+j)).frame_nr = img(P(total_blocks*block_size+j)).frame_nr;
    end

    %save the foreground results in several mat files, so that we don't get one big file
    %(nr_perFile foregrounds per file)
    nr_files = ceil(nr_frames/params.nr_perFile);
    fprintf('getForeground: save results...');
    for j=1:nr_files
        if j==1;rem=0;end
        for r=1:rem;fprintf('\b');end;
        fprintf('%i/%i',j,nr_files);
        rem = numel(num2str(j))+numel(num2str(nr_files))+1;

        take = (j-1)*params.nr_perFile+1:min(j*params.nr_perFile,length(rpca_res));
        patch = rpca_res(take);
        %save it as version 7.3 so that we can load the foreground one by one
        %without the need of loading all
        save([out_folder,sprintf('/%03d_rpca',j)],'patch','-v7.3');
    end
    fprintf('\n');
end
