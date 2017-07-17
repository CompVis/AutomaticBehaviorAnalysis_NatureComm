function [seqmatch, seqdist] = calcSeqDist(dict_trajectory, query_trajectory,sugar)
%calcSeqDist    -   This function finds the best matching between a query
%                   grasp and a grasp which belongs to the sequence dictionary
%
% Inputs:
%   dict_trajectory     - structure, which contains the information about
%                         the grasp belonging to the dictionary
%   query_trajectory    - structure, which contains the information about
%                         the query grasp
%
% Subfunctions: cplexbilp: solves binary integer programming problems,
%                          published by IBM (license required)
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    %set some parameters
    window_size = 5; 
    knn_num = 3;

    appsigma = 10;
    xysigma = 400;  
        
    outlier_cost = 10;
    crossing_cost = .5;

    %% collect the information
    dict_scores = dict_trajectory.scores;
    dict_frames = size(dict_scores,1);
    %threshold the scores
    dict_scores = dict_scores .* (dict_scores > 0);
    dict_track = dict_trajectory.coords;
    %adjust the coords to the sugar
    dict_track = dict_trajectory.sugar-dict_track;

    query_scores = query_trajectory.scores;
    query_frames = size(query_scores,1);
    %threshold the scores
    query_scores = query_scores .* (query_scores > 0);
    query_track = query_trajectory.coords;
    query_track = sugar-query_track;

    % appearance, location and overall matching probabilities
    appprob = exp( - pdist2(dict_scores, query_scores) / appsigma);
    xyprob = exp( - pdist2(dict_track, query_track) / xysigma);
%     prob = appprob .* xyprob.*lengthprob;
    prob = appprob .* xyprob;
    
    cost_mat = Inf(dict_frames, query_frames + 1);
    cost_mat(:,1) = outlier_cost;
    
    %% take only several best matches in each frame
    %(knn_num)
    for i = 1:dict_frames
        
        % range of indexes in the second sequence
        t1 = i+round(abs(query_frames/2-dict_frames/2))-window_size;
        t2 = i+round(abs(query_frames/2-dict_frames/2))+window_size;
%         t1 = i + round((query_frames - dict_frames)/2) - window_size;
%         t2 = i + round((query_frames - dict_frames)/2) + window_size;
        winIdx = (max(t1,1):min(t2,query_frames));
         
        if (~isempty(winIdx))
            [~,idx] = sort(prob(i,winIdx), 'descend');
            winIdx = winIdx(idx(1:min(knn_num, numel(idx))));
            cost_mat(i, winIdx+1) = -log(prob(i, winIdx));
        end
    end
    
    %% construct input for cplex algorithm
    f = [];
    for i = 1:dict_frames - 1
        
        Im = find(~isinf(cost_mat(i,:)));
        In = find(~isinf(cost_mat(i+1,:)));
        
        for m = 1:numel(Im)
            for n = 1:numel(In)
                
                cost = cost_mat(i,Im(m)) + cost_mat(i+1,In(n));

                if (i == 1)
                    cost = cost + cost_mat(i,Im(m));
                end
                
                if (i == dict_frames-1)
                    cost = cost + cost_mat(i+1,In(n));
                end
                
                %crossover penalization
                if (Im(m)>1 & In(n)>1 & Im(m)>In(n))
                    cost = cost + crossing_cost;
                end
                %penalize repetitions
%                 if 
                
                
                %length penalization
%                 v1 = abs(query_frames-dict_frames);
%                 length_cost = v1;
%                 
%                 cost = cost+0.1*length_cost;

                f(end+1,:) = [i, Im(m), i+1, In(n), cost];
            end
        end
    end
    
    % specify equality constraints for the binary integer program
    Aeq = []; beq = [];
    
    for i = 1:dict_frames-1
        
        %equality constraint, that you have to choose exactly one or outlier 
        idx = find(f(:,1)==i);
        
        Aeq(end+1, 1:size(f,1)) = 0;
        Aeq(end, idx) = 1;
        beq(end+1, 1) = 1;
        
        if (i == 1)
            continue
        end
        
        nbs = unique(f(idx,2));
        
        for j = 1:numel(nbs)
            
            idx1 = find(f(:,1)==i & f(:,2)==nbs(j));
            idx2 = find(f(:,3)==i & f(:,4)==nbs(j));
            
            Aeq(end+1, 1:size(f,1)) = 0;
            Aeq(end, idx1) = 1;
            Aeq(end, idx2) = -1;
            beq(end+1, 1) = 0;
        end
    end
    
    %%  solve the binary integer program
    [x, seqdist] = cplexbilp(f(:,5), [], [], Aeq, beq);
    
    %% save the result
    seqmatch = zeros(1, dict_frames);
    seqmatch(f(logical(x),1)) = f(logical(x),2)-1;
    seqmatch(f(logical(x),3)) = f(logical(x),4)-1;
    %adjust seqdist
    seqdist = seqdist+0.7*abs(query_frames-dict_frames);
end
