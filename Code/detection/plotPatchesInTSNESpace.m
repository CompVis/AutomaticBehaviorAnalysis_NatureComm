function plotPatchesInTSNESpace(fl)
%plotPatchesInTSNESpace -  This function plots the embedding of some
%                          randomly chosen detections (after reducing
%                          the dimensionality with T-SNE)

%
% Inputs:
%   fl              - structure of required folder paths
%                     (fl.pre, fl.frames, fl.det)
%
% Subfunctions: tsne: implementation of Laurens van der Maaten 
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
    
    %set prior
    framesGrasps = cellfun(@length,frames);
    loc = [];
    for i=1:length(framesGrasps)
        loc(end+1:end+framesGrasps(i)) = [1:framesGrasps(i)]/framesGrasps(i);
    end
    
    
    %compute the tsne for all patches
    patch_embedding = [];
    for g=1:length(frames2)
        patch_embedding(end+1,:) = [g,loc(g),scores2(g,:)];
    end
    %set negative scores to 0
    patch_embedding(:,3:end) = patch_embedding(:,3:end) .* ...
        (patch_embedding(:,3:end) >= 0);
    T =20;
    addpath(genpath('toolboxes/tsne_matlab'));
    dim = 2;
    tsne_scores = tsne([T*patch_embedding(:,2),...
        patch_embedding(:,3:end)], [], dim);
    
    %load aligned grid
    load([fl.pre,'/alignedGrid.mat']);
    
    rnd_idx = randperm(length(frames2));
    
    figure;
    colors = {[1,1,0],[0,1,1]};
    for i=rnd_idx(1:50)
       
        %plot the current frame in the tsne-embedding-space
        f = frames2(i);
        c = coords2(i,:);
        tsne_res = rot90(tsne_scores(i,:));
        %set y to - because we flip the image
        tsne_res(2) = -tsne_res(2);
        
        img = imread([fl.frames,sprintf('/%06i.jpg',f)]);
        img = img(newStart(2):end,newStart(1):end,:);
        img_box = img(c(2)-50:c(2)+50,c(1)-50:c(1)+50,:);
        %y axis goes pos to neg (from top left)
        img_box = flipud(img_box);
        imgx = [tsne_res(1)-4.5,tsne_res(1)+4.5];
        imgy = [tsne_res(2)-4.5,tsne_res(2)+4.5];
        imagesc(imgx,imgy,img_box);hold on;
        
        
        alpha = patch_embedding(i,2);
        c = alpha * colors{1,1} + (1-alpha) * colors{1,2};
        
        rectangle('Position',[imgx(1),imgy(1),9,9],'EdgeColor',c,'LineWidth',1);
        
        xlim([-100,100]);
        ylim([-100,100]);
        set(gca,'YDir','normal')
        axis equal;
    end
end
