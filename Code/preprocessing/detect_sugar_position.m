function sugar = detect_sugar_position(fl,nr_frames,ROI)
%DETECT_SUGAR_POSITION -  This function computes the default position of
%                          the sugar pellet
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames)
%   nr_frames       - nr of frames in video 
%   ROI             - [x,y,width,heigth] 
%                     coordinates of the area where the sugar pellet is
%                     expected
% Outputs:
%   sugar           - [x,y] coordinates of the sugar pellet

% Author: Biagio Brattoli, Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

if ~exist([fl.pre,'/sugar_location.mat'],'file')
    
    if nargin<4
        ROI = [500,730,150,315];
    end
    
    %take only a few images out of the video (choose linearly)
    %for getting the sugar location
    nr_choice = min(nr_frames,2000);
    framesChoice = 1:floor(nr_frames/nr_choice):nr_frames;
    circles = -ones(numel(framesChoice),2);
    parfor ii=1:numel(framesChoice)
        frame = imread([fl.frames,sprintf('/%06i.jpg',framesChoice(ii))]);

        [centers, radii] = imfindcircles(frame,[10 30],'Sensitivity',0.82,'Method','twostage');

        if isempty(centers); continue; end

        circles(ii,:) = centers(1,:);
    end
    detections = circles(circles(:,1)~=-1,:);

    detections(detections(:,1)<ROI(1),:)=[];
    detections(detections(:,1)>ROI(2),:)=[];
    detections(detections(:,2)<ROI(3),:)=[];
    detections(detections(:,2)>ROI(4),:)=[];

    [pdfx]= ksdensity(detections(:,1));
    [pdfy]= ksdensity(detections(:,2));

    [~,x] = max(pdfx);
    [~,y] = max(pdfy);
    x = detections(x,1);
    y = detections(y,2);

    sugar = [x,y];

    save([fl.pre,'/sugar_location.mat'],'sugar');
else
    load([fl.pre,'/sugar_location.mat'],'sugar');
end

end