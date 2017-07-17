function getGrasps(fl,cellSize,vis)
%getGrasps -  This function divides the detections in consecutive grasp trials
%
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames, fl.det)
%   cellSize        - size of cells used to create the HOG descriptors
%   vis             - 1 for plotting the results, 0 otherwise
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    thresh_distShelf = 0.08;
    jj=1;
    
    %load the detections
    load([fl.det,'/finalDetection.mat']);
    coords = trajectory.chosen_coords;
    frame_nr = trajectory.frame_nr;
    
    %% divide the detections in chunks
    %(if the detection is interrupted by a NaN -> new chunk)
    frames = frame_nr;
    frames(isnan(coords(:,1))) = [];
    coords(isnan(coords(:,1)),:) = [];
    diff = abs(frames(1:end-1)-frames(2:end));
    idx = find(diff>3);
    idx = [0,idx,length(frames)];
    
    %for loop over the chunks
    for i=1:length(idx)-1
        
        idx_i = idx(i)+1:idx(i+1);
        %a grasp should have at least 5 frames
        if length(idx_i)<5;continue;end
        %convert from hog space to x-y-space
        coord = cellSize*coords(idx_i,:);
       
        frames_i = frames(idx_i);
        newCoord = coord;
        coord2 = coord;
        %load sugar
        load([fl.pre,'/sugar_location.mat']);
        %load shelf
        load([fl.pre,'/shelf.mat']);
 
        
        %apply moving average filter for computing values for nans
        %if there are single NaNs inbetween
        coord2(:,1) = smooth(coord2(:,1),5,'moving');
        smoothY = smooth(coord2(:,2),7,'moving');
        coord2(isnan(coord2(:,2)),2) = smoothY(isnan(coord2(:,2)));        
    
        %plot this chunk
        img = imread([fl.frames,sprintf('/%06i.jpg',frames_i(1))]);
        if vis
            for f=1:length(frames_i)
                %plot all detections
                img = imread([fl.frames,sprintf('/%06i.jpg',frames_i(f))]);
                img = img(newStart(2):end,newStart(1):end,:);
                imshow(img);title(num2str(frames_i(f)));hold on;
                coord_f = coord2(f,:);
                rectangle('Position',[coord_f(1)-50,coord_f(2)-50,100,100],'EdgeColor','r');
                hold off;
                waitforbuttonpress;
            end
        end

        x = coord2(:,1);
        y = coord2(:,2);
        %compute distance to sugar
%         load([fl.pre,'/alignedGrid.mat']);
        x_sugar = x-sugar(1);
        
        
        %get the peaks
        [pks,locs,w,p] = findpeaks(x_sugar);
        if vis
            findpeaks(x_sugar);waitforbuttonpress;
        end
        %% go through all maxima
        
        %delete some maxima
        delM = find(((leftLine-x(locs))/size(img,2))>thresh_distShelf |...
             w<5 | p<10);
         pks(delM) = [];
         locs(delM) = [];
         w(delM) = [];
         p(delM) = [];
         
        %get the minima
        mini = [];
        min_idx = [];
        for m=1:length(pks)
            %get minimum before current max
            if m>1
                minRangeBefore = [max(locs(m)-10,locs(m-1)):locs(m)-1];
            else
                minRangeBefore = [max(locs(m)-10,1):locs(m)-1];
            end
            [mini((m-1)*2+1),min_idx((m-1)*2+1)] = min(x_sugar(minRangeBefore));
            min_idx((m-1)*2+1) = min_idx((m-1)*2+1)+minRangeBefore(1)-1;
            %get minimum after the current max
            if m~=length(pks)
                minRangeAfter = [locs(m)+1:min(locs(m)+15,locs(m+1))];
            else
                minRangeAfter = [locs(m)+1:min(locs(m)+15,size(x_sugar,1))];
            end
            [mini((m-1)*2+2),min_idx((m-1)*2+2)] = min(x_sugar(minRangeAfter));
            min_idx((m-1)*2+2) = min_idx((m-1)*2+2)+minRangeAfter(1)-1;
        end
        
        %plot the coordinates
        if vis
            clf;
            plot(frames_i,x_sugar,'Color','k');xlabel('frames');ylabel('dist\_sugar');
%             set(gca,'Ydir','reverse');
            hold on;
            %plot zero line (sugar position)
            plot(frames_i,zeros(1,length(frames_i)),'Color','k');
            %plot shelf position
            plot(frames_i,repmat(leftLine-sugar(1),[1,length(frames_i)]),'Color','r');
            takeNegatives = 1;
            for mm=1:length(pks)
                plot(min_idx(takeNegatives)+frames_i(1)-1,mini(takeNegatives),'*r');
                takeNegatives = takeNegatives+1;
                plot(locs(mm)+frames_i(1)-1,pks(mm),'*b');
                plot(min_idx(takeNegatives)+frames_i(1)-1,mini(takeNegatives),'*r');
                takeNegatives = takeNegatives+1;
            end
%             set(gcf,'Position',[1986,151,1615,971]);
            hold off;shg;waitforbuttonpress;
        end
        %plot the frames of the grasp and save the grasp
        for m=1:length(pks)
            idx_range = min_idx((m-1)*2+1):min_idx((m-1)*2+2);
            if vis
                for f=1:length(idx_range)
                    %plot all detections
                    clf;
                    img = imread([fl.frames,sprintf('/%06i.jpg',frames_i(idx_range(f)))]);
                    imshow(img);title(num2str(frames_i(idx_range(f))));hold on;
                    coord_f = coord2(idx_range(f),:);
                    if ~isnan(coord_f(1))
                        rectangle('Position',[coord_f(1)-50,coord_f(2)-50,100,100],'EdgeColor','r');
                        title([num2str(f),'/',num2str(length(idx_range))]);
                    else
                        title('NaN');
                    end
                    hold off;%set(gcf,'Position',[1986,151,1615,971]);
                    waitforbuttonpress;
                end
            end
            grasps(jj) = struct(...
                'coords',coord2(idx_range,:),...
                'coordsSmoothed',newCoord(idx_range,:),...
                'frames',frames_i(idx_range));
            jj=jj+1;
        end
    end
    if ~exist('grasps','var');grasps = [];end;
    %save all grasps
    save([fl.det,'/grasps.mat'],'grasps');

