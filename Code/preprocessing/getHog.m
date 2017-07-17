function getHog(fl,params)
%getHOG -  This function computes the HOG descriptor for every frame in the
%          video
%
% Inputs:
%   fl              - structure of required folder paths (fl.pre, fl.frames)
%   params          - structure of required parameters
%
% Other m-files required: getHogShelfRemoval_sugarAligned
%
% Author: Uta Büchler
% Heidelberg Collaboratory for Image Processing (HCI), Heidelberg
% email address: uta.buechler@iwr.uni-heidelberg.de
% January 2017

    hog_folder = [fl.pre,'/hog'];
    if ~exist(hog_folder,'dir')
        mkdir(hog_folder);
    end

    foregr_folder = [fl.pre,'/rpca'];

    %as in foreground: group several HOGs
    nr_files = numel(dir([foregr_folder,'/*.mat']));
    for f=1:nr_files
        data_name = sprintf('%03d_hog.mat',f);

        %check if this file already exists, if yes go to the next block
        if exist([hog_folder,'/',data_name],'file');continue;end


        %load the foreground
        l_f = load([foregr_folder,sprintf('/%03d_rpca.mat',f)]);
        foregr = l_f.patch;
        frames_ids = [foregr(:).frame_nr];

        %load the imgs which correspond to the foregrounds 'foregr'
        ii=1;
        imgs = [];
        for i=frames_ids
            img = imread([fl.frames,sprintf('/%06d.jpg',i)]);
            imgs(ii).cdata = img;
            ii=ii+1;
        end

        patch = []; 
        for d=1:length(imgs)
            frame_id = frames_ids(d);
            frame_d = imgs(d).cdata;
            foregr_d = foregr(d).cdata;

            if ~isempty(foregr_d)
                [hog_orig,hog,mask_morph] = getHogShelfRemoval_sugarAligned(...
                    fl.pre,frame_d,foregr_d,params);

                patch(d).mask = mask_morph;
                patch(d).hog = hog;
                patch(d).frame_nr = frame_id;
                patch(d).hog_orig = hog_orig;
            else
                patch(d).mask = [];
                patch(d).hog = [];
                patch(d).frame_nr = frame_nr;
                patch(d).hog_orig = [];
            end      
        end
        parsave([hog_folder,'/',data_name],patch);
    end
end
