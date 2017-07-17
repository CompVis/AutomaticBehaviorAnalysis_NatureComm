function matchAllSeqs(fl)
%matchAllSeqs -  This function finds the best matching between all detected
%                grasps and the sequence dictionary which was created earlier.
%                It leads to the second embedding which consists of the
%                sequence distance between the ith grasp and all members of
%                the sequence dictionary
%
% Inputs:
%   fl              - structure of required folder paths
%                     (fl.pre, fl.frames, fl.det, fl.seqMatch)
%
% Other m-files required: calcSeqDist
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    if ~exist([fl.seqMatch,'/seqmatching.mat'],'file')
        %load trajectory of the current video
        load([fl.det,'/firstEmbeddingGrasps.mat']);

        %load dictionary
        load('sequence_embedding/sequenceDictionary.mat');
    
        %do sequence matching for all grasps of the current video with all
        %grasps which belong to the sequence dictionary
        load([fl.pre,'/sugar_location.mat']);
        fprintf('matchAllSeq...');
        rem = 0;
        for g=1:length(traj)
            for r=1:rem;fprintf('\b');end;
            fprintf('%i/%i',g,length(traj));
            rem = numel(num2str(g))+numel(num2str(length(traj)))+1;
            
            for d=1:length(traj_dict)    
                [seqmatch{g,d}, seqdist(g,d)] = calcSeqDist( ...
                            traj_dict(d),traj(g),sugar);
            end
        end
        save([fl.seqMatch,'/seqmatching.mat'],'seqmatch','seqdist');
        fprintf('\n');
    end
end






