function [hog_orig,hog,mask_morph] = getHogShelfRemoval_sugarAligned(...
    folder_pre,frame,foregr,params)
%getHogShelfRemoval_sugarAligned -  This function computes the HOG descriptor
%                                   of the current frame, where the cells
%                                   are adjusted to the sugar position and
%                                   the vertical lines of the shelf are
%                                   removed from the result
%
% Inputs:
%   folder_pre      - folder path of the preprocessing
%   frame           - image of the current frame
%   foregr          - foreground map of the current frame
%   params          - structure of required parameters
%
% Outputs:
%   hog_orig        - HOG descriptor computed by the function vl_hog
%   hog             - hog_orig after removing the vertical lines of the
%                     shelf
%   mask_morph      - binary mask of motion, created using the foreground
%                     and a morphological dilation
%
% Subfunctions: vl_hog: belongs to the library vlfeat
%               (http://www.vlfeat.org/)
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    cellSize = params.cellSize;
    %load mean frame (needed for removing strong horizontal lines and for
    %the mask which is applied during the detection (step after computing
    %the hog descriptor))
    load([folder_pre,'/mean_frame.mat']);

    %% align the grid on the sugar position
    %(necessary when comparing coordinates between different videos, where the sugar position can be
    %different)
   
    %load sugar
    load([folder_pre,'/sugar_location.mat']);
   
    xstr = num2str(sugar(1));
    ld_x = xstr(:,end);
    alignment(1) = str2num(ld_x)-1;
    %if it is -1, the sugar orginially would lie on the last pixel of the
    %ith cell (ld_x = 0), set it to +1, so the sugar lies then in the next cell
    if alignment(1)<=0
        alignment(1) = 9;
    end
    ystr = num2str(sugar(2));
    ld_y = ystr(:,end);
    alignment(2) = str2num(ld_y)-1;
    if alignment(2)<=0
        alignment(2) = 9;
    end
    %first variant: delete the left part, but then the sugar position needs
    %to be adjusted (later for graphics: add (plus) 'newStart' to the coordinates in spatial
    %space, not in HOG space, or plot the images without the first few columns/rows,
    %but then the sugar pos needs to be changed (sugar-alignment = sugar_new))
    sugar_new = sugar-alignment;
    newStart = alignment+[1,1];
    frame = frame(newStart(2):end,newStart(1):end,:);
    save([folder_pre,'/alignedGrid.mat'],'newStart','sugar_new');
   
    %adjust foreground as well (because of the change of frame) ->
    %foreground is needed for the mask, which has the same dimensions as the
    %hog result
    foregr = foregr(newStart(2):end,newStart(1):end,:);
   
   
    %% get the hog descriptor
    numCellsX = floor(size(frame,2)/cellSize);
    numCellsY = floor(size(frame,1)/cellSize);
    frame_cell = frame(1:numCellsY*cellSize,1:numCellsX*cellSize,:);
    hog_orig = vl_hog(im2single(frame_cell),cellSize);

   % compute hog of mean_frame
    frame_mean = mean_frame;
    numCellsX = floor(size(frame_mean,2)/cellSize);
    numCellsY = floor(size(frame_mean,1)/cellSize);
    frame_mean_cell = frame_mean(1:numCellsY*cellSize,1:numCellsX*cellSize,:);
    hog_mean =vl_hog(im2single(frame_mean_cell),cellSize);

    hog_19 = sum(hog_mean(:,:,19),1);
    [~,idx_coarse] = sort(hog_19,'descend');

    % remove shelf lines in hog
    hog_frame_coarse2 = hog_orig;
    idx2 = round(median(idx_coarse(1:4)));
    idx_coarse = max(1,idx2-3):min(idx2+3,length(idx_coarse));
    for h=1:length(idx_coarse)
        sum_all = sum(hog_orig(:,idx_coarse(h),:),3);
        sum_all = sum_all-hog_orig(:,idx_coarse(h),1)-...
            hog_orig(:,idx_coarse(h),19)-hog_orig(:,idx_coarse(h),10);
        mean_all1 = sum_all/28;
        hog_frame_coarse2(:,idx_coarse(h),1) = mean_all1;
        hog_frame_coarse2(:,idx_coarse(h),19) = mean_all1;
        hog_frame_coarse2(:,idx_coarse(h),10) = mean_all1;
    end
    hog = hog_frame_coarse2;

    %% get the mask (from the foregr)
    %edit foregr
    s_f = size(foregr);
    foregr_new = foregr;
    %delete the region under the sugar (the reflection), take sugar_new,
    %because foreground is already aligned
    foregr_new(round(sugar_new(2)+size(foregr,1)*0.02):end,round(sugar_new(1)-0.5*(s_f(1)-sugar_new(1))):end)=0;
    
    % get mask in hog cells
    cellSize_f = cellSize*params.resize_value;
    numCellsX = floor(size(foregr_new,2)/cellSize_f);
    numCellsY = floor(size(foregr_new,1)/cellSize_f);
    foregr_cell = foregr_new(1:numCellsY*cellSize_f,1:numCellsX*cellSize_f);
    mask = imresize(foregr_cell,[size(hog_orig,1), size(hog_orig,2)],'box');
    mask_coarse = mask>params.thresh_foregr;
    mask_morph = imdilate(mask_coarse,ones(3,3));
end
