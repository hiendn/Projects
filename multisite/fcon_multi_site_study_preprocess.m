 
% Create the inputs of and launch the NIAK_PIPELINE_FMRI_PREPROCESS on the
% specified dataset (1000 fcon dataset)
clear all

p=genpath('/home/bellec_group/niak-2013-07-12/');
addpath(p);


pipeline = [];
opt_pipe = [];
gsc = {true,false};
sites = {'Atlanta', 'Baltimore', 'Berlin', 'Cambridge', 'Newark', 'NewYork_b', 'Oxford', 'Queensland', 'SaintLouis' };

for idx_gsc = 1:2
for idx_sites = 1:length(sites)
	path_raw_fmri   = ['/home/danserea/database/multisite/fcon_1000_raw/raw_mnc/' sites{idx_sites} '/'];
        %path_preprocess = '/sb/project/gsf-624-aa/database/aveugle/fmri_preprocess_exp3/';
        path_preprocess = ['/home/danserea/database/multisite/fcon_1000_preprocess/' sites{idx_sites} '/fmri_preprocess_gsc' int2str(gsc{idx_gsc}) '/'];
	%/data/lepore/mpelland/minc_conv/anat/CB/VD_AlCh

	files_in = fcon_grab_raw(path_raw_fmri);

	 if strcmp('Cambridge',sites{idx_sites})
                opt.tune(1).subject = '88445';
                opt.tune(1).param.slice_timing.flag_center = true;
                opt.tune(2).subject = '78552';
                opt.tune(2).param.slice_timing.flag_center = true;
        end

	%motion+
	%opt.regress_confounds.flag_wm = true;
	%opt.regress_confounds.flag_vent = true;
	%opt.regress_confounds.flag_motion_params = true;
	%opt.regress_confounds.flag_scrubbing = false;
	%opt.regress_confounds.thre_fd = 0.5;

	% multivar
	opt.regress_confounds.flag_gsc = gsc{idx_gsc};
	%opt.corsica.flag_skip = true;


	%% Building the optional inputs
	opt.folder_out = path_preprocess; 
	opt.size_output = 'all';

	%%%%%%%%%%%%%%%%%%%%
	%% Bricks options %%
	%%%%%%%%%%%%%%%%%%%%

	%% Slice timing
	opt.slice_timing.flag_skip = true;
	%opt.slice_timing.type_acquisition = 'interleaved ascending'; % Slice timing order (available options : 'sequential ascending', 'sequential descending', 'interleaved ascending', 'interleaved descending')
	%opt.slice_timing.type_scanner     = 'Siemens';               % Scanner manufacturer. Only the value 'Siemens' will actually have an impact
	%opt.slice_timing.delay_in_tr      = 0;                       % The delay in TR ("blank" time between two volumes)

	%% Motion correction (niak_brick_motion_correction)
	%opt.motion_correction.suppress_vol = 0;             % Remove the first three dummy scans

	%% Linear and non-linear fit of the anatomical image in the stereotaxic
	%% space 
	opt.t1_preprocess.nu_correct.arg = '-distance 50'; % Parameter for non-uniformity correction. 200 is a suggested value for 1.5T images, 25 for 3T images. If you find that this stage did not work well, this parameter is usually critical to improve the results.

	% T1-T2 coregistration (niak_brick_anat2func)
	opt.anat2func.init = 'identity'; % An initial guess of the transform. Possible values 'identity', 'center'. 'identity' is self-explanatory. The 'center' option usually does more harm than good. Use it only if you have very big misrealignement between the two images (say, 2 cm).

	%% Temporal filetring (niak_brick_time_filter)
	opt.time_filter.hp = 0.01; % Apply a high-pass filter at cut-off frequency 0.01Hz (slow time drifts)
	opt.time_filter.lp = Inf; % Do not apply low-pass filter. Low-pass filter induce a big loss in degrees of freedom without sgnificantly improving the SNR.

%% Correction of physiological noise (niak_pipeline_corsica)
	opt.corsica.sica.nb_comp = 60;
	opt.corsica.component_supp.threshold = 0.15;

	%% Resampling in the stereotaxic space (niak_brick_resample_vol)
	%opt.resample_vol.interpolation       = 'tricubic'; % The resampling scheme. The most accurate is 'sinc' but it is awfully slow
	opt.resample_vol.voxel_size          = [3 3 3];    % The voxel size to use in the stereotaxic space

	%% Spatial smoothing (niak_brick_smooth_vol)
	opt.bricks.smooth_vol.fwhm = 6; % Apply an isotropic 6 mm gaussin smoothing.

	%% Region growing
	opt.region_growing.flag_skip = true; % Turn on/off the region growing
	%opt.template_fmri = '/home/cdansereau/svn/niak/trunk/template/roi_aal.mnc.gz';

	%% PVE
	opt.pve.flag_skip = true;

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%% Generation of the pipeline %%
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	opt.flag_test = true;
	%opt.psom.max_queued = 15; % Please try to use the two processors of my laptop, thanks !

	[pipeline_tmp,opt_tmp] = niak_pipeline_fmri_preprocess(files_in,opt);

	pipeline = psom_merge_pipeline(pipeline,pipeline_tmp,[sites{idx_sites} '_gsc_' int2str(gsc{idx_gsc})]);
	end
end

opt_tmp.psom.restart = {'sub88445','sub78552'};
opt_tmp.psom.qsub_options = '-q qwork@ms -l walltime=06:00:00';
psom_run_pipeline(pipeline,opt_tmp.psom)





