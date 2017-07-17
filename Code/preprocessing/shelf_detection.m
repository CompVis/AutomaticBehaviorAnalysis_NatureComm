function [leftLine,rightLine] = shelf_detection(nr_frames,folder_frames,file,show)
%SHELF_DETECTION -  This function computes the beginning of the shelf
%                   (the vertical Plexiglas where the rats need to grasp
%                   through to receive the sugar pellet)
% Inputs:
%   nr_frames       - nr of frames in whole video 
%   folder_frames   - path of the frames of current video
%   file            - path+file name where the shelf coordinates are saved
%   show            - 1 for plotting the detected shelf on top of the
%                     first frame, 0 otherwise
%
% Outputs:
%   leftLine        - x coordinates of the beginning of the Plexiglas
%   rightLine       - x corrdinate of the end of the Plexiglas

% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    if nargin<4
        show = 0;
    end
    if ~exist(file,'file')
        %take at most 200 frames out of the video for estimating the position
        %of the shelf
        rand_frames = randsample(1:nr_frames,min(200,nr_frames));

        %load all images which are used to estimate the shelf
        ii=1;
        patch = [];
        for i=rand_frames
            %load all images
            patch(ii).cdata = imread([folder_frames,sprintf('/%06i.jpg',i)]);
            ii=ii+1;
        end

        %set approximate shelf width
        shelf_width = [20:30];
        %get shelf position for every frame
        leftLine = [];
        rightLine = [];
        for i = 1:numel(patch)
            im = im2double(patch(i).cdata);
            imgray = rgb2gray(im);
            imgray = imadjust(imgray);

            imgray = imgray(round(1/2*end):end,:);

            offset = round(0.6 * size(imgray,2));
            grad = conv2(imgray, [1 0 -1; 2 0 -2; 1 0 -1], 'same');
            grad_proj = sum(abs(grad) > 0.2) / size(imgray,1);

            I = find(grad_proj(offset+1:end) > 0.3, 1);
            [~, J] = max(grad_proj(offset+I:min(offset+I+5, numel(grad_proj))));
            if ~isempty(I) && ~isempty(J)
                I = I + J(1) - 1;
                [~,J] = max(grad_proj(min(offset + I + shelf_width, numel(grad_proj))));

                leftLine(end+1) = I + offset;
                rightLine(end+1) = I + offset + shelf_width(J(1));

            end
        end
        %get median
        if ~isempty(leftLine)
            leftLine = median(leftLine);
            rightLine = median(rightLine);
        else
            disp('noLine');
        end
        save(file,'leftLine','rightLine');
    else
        load(file);
    end

    if show
        img = imread([folder_frames,sprintf('/%06i.jpg',1)]);
        imshow(img);hold on;
        plot([leftLine,leftLine],[0,size(img,1)],'r');
        plot([rightLine,rightLine],[0,size(img,1)],'b');
    end
end
