% Recovery analysis  -  This scipt produces a 2D plot in which every
% recoding session is localized based on the similarity between healty and
% impaired behaviour.
% Inputs:
%   samples_st.mat and samples_nogo.mat contain the embedding of every
%   grasping sequences extracted from all videos group based on cohort and
%   time
%
% Outputs:
%   plot the produced figure
% Author: Biagio Brattoli
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: biagio.brattoli@iwr.uni-heidelberg.de
% January 2017
%%
% Stimulation/Training
samples = importdata('samples_stimulation.mat');
[pvalues, pvalues_std] = distributionSimilarity(samples);

% Anti-nogo/Training
samples = importdata('samples_nogo.mat');
[pvalues_nogo, pvalues_std_nogo] = distributionSimilarity(samples);

%% Plot each group based on the distance between Baseline (before the surgery) and 2days (right after the surgery)
pvalues(:,:,5) = pvalues_nogo(:,:,end);
pvalues_std(:,:,5) = pvalues_std_nogo(:,:,end);

plot_triangulation(pvalues,pvalues_std);
