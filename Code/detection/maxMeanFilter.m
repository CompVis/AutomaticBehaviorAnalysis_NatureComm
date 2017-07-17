function [prob_frames_new,chosen_max_new] = maxMeanFilter(d,dist_thresh,chosen_max,prob_frames,trajectory,trans2,p_positionPrior)
%maxMeanFilter    -   This function uses a mean Filter to update/correct
%                     the detection position
%
% Inputs:
%   d               - original nr of extracted detections per frame
%   dist_thresh     - upper bound of allowed distance between the average
%                     coordinates and the jth maximum
%   chosen_max      - index of chosen maximum for every frame
%   prob_frames     - probability of the chosen maximum
%   trajectory      - information about the current frame
%   trans2          - normalized transition probability
%   p_positionPrior - region where the paw is expected
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017    
    
    chosen_max_new = chosen_max;
    prob_frames_new = prob_frames;
    %start at third frame, because two frames before t and two frames after
    %t are used to get the mean
    stop = length(chosen_max)-2;
    for t=3:stop
        if isnan(chosen_max(t));continue;end
        %% get the mean of the 5 coordinates
        %(2 frames before,2 frames after and the coordinates of the frame
        %itself)
        
        %sum up the coordinates of the frames before and the frame itself
        %(if possible)
        nr_inSum = 0;
        sum_x = 0;
        sum_y = 0;
        scores = trajectory.track(t,3,:);
        scores = scores./sum(scores);
        if ~isnan(chosen_max_new(t-1))
            pos_b1 = trajectory.track(t-1,1:2,chosen_max_new(t-1));
            sum_x = sum_x+pos_b1(1);
            sum_y = sum_y+pos_b1(2);
            nr_inSum = nr_inSum+1;
        end
        if ~isnan(chosen_max_new(t-2))
            pos_b2 = trajectory.track(t-2,1:2,chosen_max_new(t-2));
            sum_x = sum_x+pos_b2(1);
            sum_y = sum_y+pos_b2(2);
            nr_inSum = nr_inSum+1;
        end
        pos_curr = trajectory.track(t,1:2,chosen_max(t));
        sum_x = sum_x+pos_curr(1);
        sum_y = sum_y+pos_curr(2);
        
        %sum up the coordinates of the frames after
        after_found = 0;
        ta = t;
        while ~after_found && ta<length(chosen_max)
            if ~isnan(chosen_max(ta+1))
                pos_a = trajectory.track(ta+1,1:2,chosen_max(ta+1));
                sum_x = sum_x+pos_a(1);
                sum_y = sum_y+pos_a(2);
                nr_inSum = nr_inSum+1;
                after_found = 1;
            else
                ta = ta+1;
            end
        end

        after_found_sec = 0;
        %start with frame after the current found one
        ta = ta+1;
        while ~after_found_sec && ta<length(chosen_max)
            if ~isnan(chosen_max(ta+1))
                pos_a = trajectory.track(ta+1,1:2,chosen_max(ta+1));
                sum_x = sum_x+pos_a(1);
                sum_y = sum_y+pos_a(2);
                nr_inSum = nr_inSum+1;
                after_found_sec = 1;
            else
                ta = ta+1;
            end
        end

        %% get the mean coordinates
        mean_x = sum_x/(nr_inSum+1);
        mean_y = sum_y/(nr_inSum+1);
        
        %% get new maximum 
        %check which maximum of the current frame is closest to the
        %mean coordinates
        
        clear dist
        %j: maximum nr.
        %t: frame nr.
        for j=1:d
            dist(j) = norm([mean_x,mean_y]-trajectory.track(t,1:2,j))*...
                (1-scores(j));
            if norm([mean_x,mean_y]-trajectory.track(t,1:2,j))>dist_thresh ||...
                    ~p_positionPrior(j,t) ||...
                    (ta==t && trans2(j,chosen_max_new(t+1),t)==0)
                dist(j) = 1000;
            end
        end
        
        %if the dist of all maxima are equal to 1000, set to NaN
        if sum(dist~=1000)<1
            chosen_max_new(t)=NaN;
            prob_frames_new(t) = NaN;
        end
        [~,chosen_max_new(t)] = min(dist);
%         prob_frames_new(t) = prob_
        if ~isnan(chosen_max_new(t-1)) && ~isnan(chosen_max_new(t))
            prob_frames_new(t) = trans2(chosen_max_new(t-1),chosen_max_new(t),t);
        else
            prob_frames_new(t) = NaN;
        end
    end %t
    %% postprocessing
    %check for moments where the prob_frames_new is very low for at
    %least 5 frames in a row (it's probably because the hand is not in
    %the expected region and a sugar or tweezer is detected)
    wrongDet = find(prob_frames_new<0.1 | isnan(prob_frames_new));
    nrWrongInARow = 0;
    idxWrongInARow = [];
    setToNaN = [];
    for i=2:length(wrongDet)
        if wrongDet(i)-wrongDet(i-1)<=5
            nrWrongInARow = nrWrongInARow+1;
            idxWrongInARow = [idxWrongInARow,wrongDet(i-1)];
        else
            if nrWrongInARow>=5
                setToNaN = [setToNaN,idxWrongInARow(1):idxWrongInARow(end)];
            end
            nrWrongInARow = 0;
            idxWrongInARow = [];
        end
    end

    prob_frames_new(setToNaN) = NaN;
    chosen_max_new(setToNaN) = NaN;
end
