Here we analyse the recovery of the animals during rehabilitation based on the grasping posture of the paw.
Given a cohort and a recovery day, we want to tell if the animal grasping is closer to a healty or impared behavior. In our case, Baseline will be consider healty animals and 2days are impared animals. The similarity between distributions from different days is computed using the pvalue from the two sample KS-test. In order to apply the KS-test we need to reduce our dimensionality from 120 to 1 dimension. We use Fisher LDA in order to project our distributions on a single dimension which maximize the distance between healty and impared animals.

As posture representation we use the embedding extracted previously and saved in the files 'samples_stimulation.mat' and 'samples_nogo.mat'.

To run the experiment:
- open MATLAB on the current directory
- open the script 'RecoveryAnalysis.m'
- run using F5 or the play button
