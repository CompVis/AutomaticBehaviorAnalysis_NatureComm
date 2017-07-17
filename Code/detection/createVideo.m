function createVideo(fl,params,status)
%createVideo -  This function creates a video using the original video
%               superimposed by the computed detections (and if requested,
%               it additionally emphasizes the individual grasps)
%
% Inputs:
%   fl              - structure of required folder paths
%                     (fl.pre, fl.frames, fl.det)
%   params          - structure of required parameters
%   status          - if status='det' show only the detections, otherwise
%                     show also the distinction in grasps
%
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    %create a video after computing the detections or after getting the
    %grasps
    bbox_size = params.bbox_size;
    cellSize = params.cellSize;
    
    %load the detections
    load([fl.det,'/finalDetection.mat']);
    frame_nr = [trajectory(:).frame_nr];
    load([fl.pre,'/alignedGrid.mat']);
    
    patch = struct('cdata',[]);
    %load all images
    fprintf('createVideo: load Images...');
    rem = 0;
    for j=1:numel(frame_nr)
        if mod(j,500)==0
            for r=1:rem;fprintf('\b');end;
            fprintf('%i/%i',j,numel(frame_nr));
            rem = numel(num2str(j))+numel(num2str(numel(frame_nr)))+1;
        end
        patch(j).cdata = imread([fl.frames,sprintf('/%06i.jpg',frame_nr(j))]);
        patch(j).cdata = patch(j).cdata(newStart(2):end,newStart(1):end,:);
    end
    fprintf('\n');
    fprintf('createVideo: create frames...');
    %for detections
    if strcmp(status,'det')
        parfor j=1:numel(patch)
            fig = figure('Visible','off');
            imshow(patch(j).cdata);hold on;

            %plot the final maximum
            if ~isnan(trajectory.chosen_max_new(j)) 
                title([num2str(j),'/',num2str(length(frame_nr))]);
                curr = trajectory.chosen_coords(j,:);
                rectangle('Position',[cellSize*curr(1)-bbox_size/2,cellSize*curr(2)-bbox_size/2,bbox_size,bbox_size],'EdgeColor','r','LineWidth',2);
            else
                title(['NaN ',num2str(j),'/',num2str(length(frame_nr))]);
            end

            M(j) = getframe(fig);
            close(fig);
        end
    
    %for the grasps
    elseif strcmp(status,'grasp')
        %load the grasps
        load([fl.det,'/grasps.mat']);
        %extract the frames to find out which frame belongs to a grasp
        frames = [grasps(:).frames];
        frames_grasps = {grasps(:).frames};
        parfor j=1:numel(patch)
            fig = figure('Visible','off');
            imshow(patch(j).cdata);hold on;
            if ~isnan(trajectory.max_nr(j)) 
                title([num2str(j),'/',num2str(length(frame_nr))]);
                curr = trajectory.chosen_coords(j,:);
                %check if this frame belongs to a grasp and if yes to which
                if sum(frames==j)>0
                    for g=1:length(frames_grasps)
                        if sum(frames_grasps{g}==j)>0
                            g_j = g;
                            break;
                        end
                    end
                    rectangle('Position',[cellSize*curr(1)-bbox_size/2,cellSize*curr(2)-bbox_size/2,bbox_size,bbox_size],'EdgeColor','b','LineWidth',2);
                    text(cellSize*curr(1)-bbox_size/2-10,cellSize*curr(2)-bbox_size/2-10,num2str(g_j),'Color','b','FontSize',20);
                else
                    rectangle('Position',[cellSize*curr(1)-bbox_size/2,cellSize*curr(2)-bbox_size/2,bbox_size,bbox_size],'EdgeColor','r','LineWidth',2);
                end
            else
                title(['NaN ',num2str(j),'/',num2str(length(frame_nr))]);
            end
            M(j) = getframe(fig);
            close(fig);
        end
    end
    
    fprintf('createVideo: save video...');
    %save the frames in 'M' as avi
    v = VideoWriter([fl.det,'/',status,'.avi']);
    v.FrameRate = 10; 
    open(v);
    for j=1:length(M)
%         if mod(j,500)==0;disp([num2str(j),'/',num2str(length(M))]);end;
        writeVideo(v,M(j));
    end
    close(v);
    fprintf(['Video saved as " \n',[fl.det,'/',status,'.avi'],'"']);
end