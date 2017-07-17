function plotNearestNeighbor(fl)
%plotNearestNeighbor -  This function plots the nearest neighbor of some
%                       randomly chosen detections
% Inputs:
%   fl              - structure of required folder paths
%                     (fl.pre, fl.frames, fl.det)
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    load([fl.det,'/firstEmbeddingGrasps.mat']);
    scores = {traj(:).scores}';
    scores2 = cell2mat(scores);
    frames = {traj(:).frames};
    frames2 = cell2mat(frames);
    coords = {traj(:).coords}';
    coords2 = cell2mat(coords);

    %compute cosine distance
    dist = squareform(pdist(scores2,'cosine'));

    %randomly choose patches
    rnd_idx = randperm(length(frames2));

    %load aligned grid
    load([fl.pre,'/alignedGrid.mat']);

    figure;
    for i=rnd_idx(1:50)
        disp(i);
        %get nearest neighbor
        dist_i = dist(i,:);
        [~,idx] = sort(dist_i);

        %plot the current frame
        f = frames2(i);
        c = coords2(i,:);
        img = imread([fl.frames,sprintf('/%06i.jpg',f)]);
        img = img(newStart(2):end,newStart(1):end,:);
        img_box = img(c(2)-50:c(2)+50,c(1)-50:c(1)+50,:);
        subplot_tight(1,11,1);imshow(img_box);
        
        %plot the nearest neighbour
        for n=2:11
            f = frames2(idx(n));
            c = coords2(idx(n),:);
            img = imread([fl.frames,sprintf('/%06i.jpg',f)]);
            img = img(newStart(2):end,newStart(1):end,:);
            img_box = img(c(2)-50:c(2)+50,c(1)-50:c(1)+50,:);
            subplot_tight(1,11,n);imshow(img_box);
        end
        waitforbuttonpress;
    end
end