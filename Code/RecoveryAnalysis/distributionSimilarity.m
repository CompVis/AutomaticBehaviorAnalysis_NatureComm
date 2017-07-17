function [pvalues, pvalues_std] = distributionSimilarity(samples)
% This function computes pairwise similarity between classes. A class is
% defined by the cohort and the recovery time. The similarity is expressed
% using p-values from the two samples KS-test. In order to apply KS-test,
% features reduction is applied using Fisher LDA. The projection maximizes
% the distance between healty (Baseline) and impaired (2days) animals. The
% projection is computed NT times each of them extracting random train
% samples which gives a more stable result.
% 
% Inputs:
%   samples - matrix of cells of shape CxD (C cohort, D time). Each cell
%   contains the sequences representation
%
% Outputs:
%   pvalues - pairwise two samples KS-test between each class. Shape DxDxC
%   pvalues_std - pvalues standard deviation. Shape DxDxC
% 
% Author: Biagio Brattoli
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: biagio.brattoli@iwr.uni-heidelberg.de
% January 2017

addpath('../toolboxes/FDA_multiclass');

ddd = [0,2,7,14,21,28,35];

dd = size(samples,2);
gg = size(samples,1);

%% LDA is used to find the best projection to separate Baseline samples from 2days samples (after the surgery)
%% LDA projection is computed sampling random training points NT times
NT = 100;
pvalues_t = zeros(dd,dd,gg,NT);
parfor TRAIN=1:NT
    % Train/Test random sampling
    trainset = [];
    train_info = [];
    testset = [];
    test_info = [];
    for d=1:dd
        for g=1:gg
            x = samples{g,d}.samples;
            if isempty(x);continue;end

            p = randperm(size(x,1));
            x = x(p,:);

            n = samples{g,d}.train_qt;
            trainset   = [trainset;x(1:n,:)];
            train_info = [train_info;repmat([g,ddd(d)],[n,1])];

            testset    = [testset;x(n+1:end,:)];
            test_info  = [test_info;repmat([g,ddd(d)],[size(x(n+1:end,:),1),1])];
        end
    end
    %% Train
    train_labels = ones(size(trainset,1),1);
    train_labels(train_info(:,2)==ddd(2) | train_info(:,2)==ddd(3)) = -1;

    [Z,W,eigval] = FDA(trainset',train_labels,1);

    scores       = testset *W; % projection of the test set
    %% compute P-Values. From each distribution it sample N0 random points and repeat 20 times
    N0=150;
    pvalues_std = -1*ones(dd,dd,gg);
    pvalues = -1*ones(dd,dd,gg);
    for g=1:gg
        for d1=1:dd
            sel = test_info(:,1) == g & test_info(:,2) == ddd(d1);
            s1 = scores(sel);
            N1 = numel(s1);
            for d2=1:dd
                sel = test_info(:,1) == g & test_info(:,2) == ddd(d2);
                s2 = scores(sel);
                N2 = numel(s2);
                if isempty(s1) || isempty(s2); continue; end
                N3 = min(N1,N2);
                N  = min(N0,N3);

                p_s = [];
                for i=1:20
                    X1 = s1(randperm(N1));
                    X2 = s2(randperm(N2));
                    X1 = X1(1:N);
                    X2 = X2(1:N);
                    [~,p] = kstest2(X1,X2);
                    p_s = [p_s;p];
                end
                pvalues(d2,d1,g)     = mean(p_s);
                pvalues_std(d2,d1,g) = std(p_s);
            end
        end
    end
    pvalues_t(:,:,:,TRAIN) = pvalues;
end
pvalues = mean(pvalues_t,4);
pvalues_std = std(pvalues_t,[],4);

end