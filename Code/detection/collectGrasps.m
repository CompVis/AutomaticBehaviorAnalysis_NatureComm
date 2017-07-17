function collectGrasps(fl)
%collectGrasps -  This function collect all grasps detected in the current
%                 video
%
% Inputs:
%   fl              - structure of required folder paths
%                     (fl.pre, fl.frames,fl.det)
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    if ~exist([fl.det,'/firstEmbeddingGrasps.mat'],'file')
        %load all grasps of the current video
        load([fl.det,'/finalDetection.mat']);
        load([fl.det,'/grasps.mat']);
        %extract the frames to find out which frame belongs to a grasp
        frames = [grasps(:).frames];
        frames_grasps = {grasps(:).frames};
        
        jj=1;
        rem = 0;
        for j=1:length(grasps)
            if mod(j,10)==0
                for r=1:rem;fprintf('\b');end;
                fprintf('%i/%i',j,length(grasps));
                rem = numel(num2str(j))+numel(num2str(length(grasps)))+1;
            end
            coords = grasps(j).coords;
            scores = [];
            for f=1:length(grasps(j).frames)
                idx = find(grasps(j).frames(f)==trajectory.frame_nr);
                file_nr = ceil(idx/200);
                a = load([fl.det,sprintf('/%03i_trajectory.mat',file_nr)]);
                pos_inFile = idx-((file_nr-1)*200);
                chosenMax = trajectory.max_nr(idx);
                if ~isnan(chosenMax)
                    scores(f,:) = a.trajectory.scores(pos_inFile,:,chosenMax);
                else
                    break;
                end
            end
            if size(scores,1)==length(grasps(j).frames)
                traj(jj) = struct(...
                    'scores',scores,...
                    'coords',coords,...
                    'frames',grasps(j).frames);
                jj = jj+1;
            end
        end
        save([fl.det,'/firstEmbeddingGrasps.mat'],'traj');
    end
end
