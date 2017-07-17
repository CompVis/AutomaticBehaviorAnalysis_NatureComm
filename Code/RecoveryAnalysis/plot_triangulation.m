function plot_triangulation(pvalues,pvalues_std)
% This function compute the localization of each class based on the distance 
% between Baseline and 2days. The localization is computed using the 
% intersaction between the two circles having Baseline and 2days as centers 
% and the distance to the target class as radius. 
% Plus saves the p-values and standard deviation in a csv file.
% 
% Inputs:
%   pvalues - pairwise p-value of shape DxDxC (C cohort, D time)
%   pvalues_std - p-value standard deviation. Shape DxDxC
%
% Outputs:
%   CSV file
%   Figure
% 
% Author: Biagio Brattoli
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: biagio.brattoli@iwr.uni-heidelberg.de
% January 2017

days    = {'Baseline','2d','7d','14d','21d','28-35d'};
cohorts = {'Delayed Training','Spontaneus recovery','Stimulation','Stimulation/Training','Anti-Nogo/Training'};

dd = numel(days);
gg = numel(cohorts);

%% Save XLS
fileID = fopen('pvalues.csv','w');
fprintf(fileID,',,');
for d=1:dd; fprintf(fileID,'%s,',days{d}); end
for i=gg:-1:1
    fprintf(fileID,'\n,%s\n,',cohorts{i});
    X = pvalues(:,:,i);
    for r=1:dd
        fprintf(fileID,'%s',days{r});
        for c=1:dd
            fprintf(fileID,',%f',X(r,c));
        end
        fprintf(fileID,'\n,');
    end
    fprintf(fileID,'\n,STD %s\n,',cohorts{i});
    X = pvalues_std(:,:,i);
    for r=1:dd
        fprintf(fileID,'%s',days{r});
        for c=1:dd
            fprintf(fileID,',%f',X(r,c));
        end
        fprintf(fileID,'\n,');
    end
end

%% Compute distance Baseline-2days
points = zeros(gg,dd,2);
for g = 1:gg
    X = pvalues(:,:,g);
    if g~=gg
        % For each cohort except Anti-Nogo/Threatment, average 28 days 
        % and 35 days
        X(1:end-2,end-1) = (X(1:end-2,end-1)+X(1:end-2,end))/2;
        X(end-1,1:end-2) = (X(end-1,1:end-2)+X(end,1:end-2))/2;
        X(:,end)=[];
        X(end,:)=[];
    end
    X = (X+X')/2; % make the similarity simmetric
    X = (1-X);  % the function circcirc needs distances
    X = (X.^2); % for visualization pourpuse
    for d=1:dd
        if d~=1 && d~=2
            r1 = X(d,1); % radius 1
            r2 = X(d,2); % radius 2
            [xout,yout] = circcirc(0,0,r1,1,0,r2); % Baseline centered in [0,0], 2days centered in [1,0]
            xout(yout<0)=[];
            yout(yout<0)=[];
        else
            xout = d-1;
            yout = 0;
        end
        if isnan(xout); continue; end
        points(g,d,:) = [xout(1),yout(1)];
    end
end

%% Plot
s = [1,-3,1,-3,1,-3,1];
cols = [0,1,0; 0.5,0.5,0.5; 0,0,1; 1,1,0; 1,0,0];
figure; hold on;
text(0.02,0.02,days{1},'FontSize',14);
text(1.01,0.01,days{2},'FontSize',14);
for d=1:dd-1
    for g = 1:gg
        Y = squeeze(points(g,:,:));
        if d>1
            text(Y(d+1,1)+0.01*s(d),Y(d+1,2)+0.01*rand(),days{d+1},'color',cols(g,:),'FontSize',14);
            plot(Y(d:d+1,1),Y(d:d+1,2),'-O','markersize',10,'color',cols(g,:),'LineWidth',2);
        else
            plot(Y(d:d+1,1),Y(d:d+1,2)+0.001*g,'-O','markersize',10,'color',cols(g,:),'LineWidth',2);
        end
        hold on
    end
    legend(cohorts)
end
