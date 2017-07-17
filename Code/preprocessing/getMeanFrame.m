function [mean_frame] = getMeanFrame(fl,nr_frames)
%getMeanFrame -  This function computes the mean frame of the whole video
%
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames)
%   nr_frames       - nr of frames in video 
%
% Outputs:
%   mean_frame      - computed mean frame of the video

% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    meanframe_file = [fl.pre, '/mean_frame.mat' ];

    if ~exist(meanframe_file,'file')

        frame_first = imread([fl.frames,sprintf('/%06i.jpg',1)]);

        sum_all = zeros(size(frame_first));
        sum_all_squared = zeros(size(frame_first));
        tic;
        notCalc = 0;
        rem = 0;
        fprintf('Calculating mean frame: Loaded images: ');
        for f=1:nr_frames
            try
                frame_f = imread([fl.frames,sprintf('/%06i.jpg',f)]);
                sum_all = sum_all+double(frame_f);
                sum_all_squared = sum_all_squared+double(frame_f).^2;
                if mod(f,1000)==0
                    for r=1:rem;fprintf('\b');end;
                    fprintf('%i/%i',f,nr_frames);
                    rem = numel(num2str(f))+numel(num2str(nr_frames))+1;
                end
            catch
                notCalc = notCalc+1;
            end
        end
        for r=1:rem;fprintf('\b');end;
        fprintf('%i/%i',f,nr_frames);
        fprintf('\n');

        mean_frame = sum_all/(nr_frames-notCalc);
        mean_squared_frame = sum_all_squared/(nr_frames-notCalc);
        std = sqrt(mean_squared_frame-mean_frame.^2);

        %save the mean and the standard deviation
        save(meanframe_file,'mean_frame','std');
    else
        load(meanframe_file);
    end
end
