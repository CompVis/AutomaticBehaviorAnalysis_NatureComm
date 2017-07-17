function getMax(fl,params,positionPrior)
%getMax -  This function chooses the most probable position of the paw out
%          of 3 previosly saved maxima (in patchDetector.m)
%
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames, fl.det)
%   params          - structure of required parameters
%   positionPrior   - sets the region where the paw is expected
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017
    
    frames_nr = params.nr_frames;
    %% set parameters
    %for Gibbs distribution
    beta_1 = 0.01;
    %max distance between maxima of consecutive frames
    dist_thresh = 15;
    %set how many max are initally used to find the paw
    d=3;
    
    %% load all detections and foregrounds
    data = dir([fl.det,'/*_trajectory.mat']);
    traj_all.scores = [];
    traj_all.track = [];
    frame_nr = [];
    foregr_all = cell(0);
    fprintf('getMax: Load data...');
    rem = 0;
    for i=1:length(data)
        for r=1:rem;fprintf('\b');end;
        fprintf('%i/%i',i,length(data));
        rem = numel(num2str(i))+numel(num2str(length(data)))+1;

        %load possible maxima
        load([fl.det,'/',data(i).name]);
        traj_all.scores(end+1:end+length(trajectory.scores),:,:) = trajectory.scores;
        traj_all.track(end+1:end+length(trajectory.track),:,:) = trajectory.track;
        %load foreground
        load([fl.pre,sprintf('/rpca/%03i_rpca.mat',i)]);
        foregr_all(end+1:end+length(patch)) = {patch(:).cdata};
        frame_nr = [frame_nr,[patch(:).frame_nr]];
        clear trajectory patch
    end
    fprintf('\n');
    
    n = length(traj_all.track);
    if n~=frames_nr
        error('Error: Not all frames are preprocessed.');
    end
             
    %% test which maxima is best for every frame
    %(get probability for every maxima)
    
    fprintf('getMax: Get best Maxima...');
    %initialize with zeros
    prob = zeros(d,n);
    %get score of the possible maxima for the first frame
    prob(:,1) = traj_all.track(1,3,1:d);
    %normalize
    prob(:,1) = prob(:,1)./sum(prob(:,1));
    %positionPrior per frame per maxima
    %(1 for coordinates are in expected region, 0 otherwise)         
    p_positionPrior = zeros(d,n);

    
    %for loop over the frames
    for t=2:n
        track_i = traj_all.track(t,:,1:d);
        track_before = traj_all.track(t-1,:,1:d);
        %for loop over maxima in frame before
        for k=1:d
            p_1 = zeros(1,d);
            x_k = track_before(1,1,k);
            y_k = track_before(1,2,k);
            if t==2
                %check if the coordinates make sense
                %if yes save if the coordinate is in the range where we
                %want to look for a paw (depending on positionPrior)
                if x_k==-1 || y_k == -1 ||...
                        y_k>size(positionPrior,1) || x_k>size(positionPrior,2)
                    p_positionPrior(k,t-1) = 0;
                else
                    p_positionPrior(k,t-1) = positionPrior(y_k,x_k);
                end
            end
            %for loop over maxima in current frame
            for j=1:d
                %compute distance between maxima k and maxima j
                distance = norm(track_i(1,1:2,j)-track_before(1,1:2,k));
                %gibbs distribution, where the energy is the distance of
                %the coordinates
                p_1(j)= exp(-beta_1*distance);
                x = track_i(1,1,j);
                y = track_i(1,2,j);

                %check if the coordinates make sense
                if x==-1 || y==-1
                    p_positionPrior(j,t) = 0;
                    score_t(j) = 0;
                else
                    if y>size(positionPrior,1) || x>size(positionPrior,1) ||...
                            track_i(1,3,j)<0.05
                        p_positionPrior(j,t) = 0;
                    else
                        p_positionPrior(j,t) = positionPrior(y,x);
                    end
                    score_t(j) = track_i(1,3,j);
                end
            end %j
            
            %combine the coordinate gibbs probability with the score (given
            %out by SVM) and the positionPrior information to get the
            %transition probability between kth maxima from the frame
            %before and all maxima in current frame
            if sum(p_positionPrior(:,t)==0)==3
                trans(k,:,t-1) = p_1.*score_t;
            else
                trans(k,:,t-1) = p_positionPrior(:,t)'.*(p_1.*score_t);
            end
        end %k

        %marginalize over k (the maxima in frame before) to get the
        %probability of maxima j in current frame
        trans1=trans(:,:,t-1);
        %for loop over the maxima of current frame
        for j=1:d
            %if the maxima does not lie in the expected region, set
            %probability to 0
            if sum(p_positionPrior(:,t)==0)==3
                prob(j,t) = 0;
            else
                %if all maxima of the previous frame does not lie in the
                %expected region
                if sum(p_positionPrior(:,t-1)==0)==3 || isnan(prob(k,t-1))
                    for k=1:d
                        prob(j,t) = prob(j,t)+(trans1(k,j)*1/3);
                    end
                else
                    for k=1:d
                       prob(j,t) = prob(j,t)+(trans1(k,j).*prob(k,t-1));
                    end
                end
            end
            %normalize probability
            if sum(prob(:,t))~=0
                prob(:,t) = prob(:,t)./sum(prob(:,t));
            end
        end

        %normalize transition probability
        trans2(:,:,t-1) = trans(:,:,t-1);
        for j=1:d
            if sum(trans(:,j,t-1))~=0
                trans2(:,j,t-1) = trans(:,j,t-1)./sum(trans(:,j,t-1));
            else
                trans2(:,j,t-1) = trans(:,j,t-1);
            end
        end
    end %t
    
    %% apply Mean Filter
    
    %choose initial maximum as the one with the highest probability
    %if all are 0, set the maximum to NaN since there is no appropriate
    %maximum in the frame
    prob_frames = NaN(1,size(prob,2));
    chosen_max = NaN(1,size(prob,2));
    for t=1:length(prob)
        if ~(sum(prob(:,t)==0)==3)
            [prob_frames(t),chosen_max(t)] = max(prob(:,t));
        end
    end
    [prob_frames_new,chosen_max_new] = maxMeanFilter(d,dist_thresh,chosen_max,...
        prob_frames,traj_all,trans2,p_positionPrior);


    %% save result
    clear trajectory
    trajectory.max_nr = chosen_max_new;
    trajectory.prob_max = prob_frames_new;
    trajectory.frame_nr = frame_nr;
    trajectory.coords = traj_all.track(:,1:2,1:d);
    %get the coordinates of the final maximum
    for i=1:length(chosen_max)
        if ~isnan(chosen_max_new(i))
            coords(i,:) = traj_all.track(i,1:2,chosen_max_new(i));
        else
            coords(i,:) = [NaN,NaN];
        end
    end
    trajectory.chosen_coords = coords;
    
    save([fl.det,'/finalDetection.mat'],'trajectory');

    fprintf('Done \n');
end
