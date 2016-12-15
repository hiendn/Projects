%% script to subtype the "rest" of adni2 resting-state

clear all

%% set up paths
path_data = '/home/atam/scratch/adni2/scores_20161207_min30vol/rmap_part/rmap_3d/';
path_sub = '/gs/project/gsf-624-aa/database2/preventad/results/subtype_admci_s07_gui_20160705/';
path_out = '/home/atam/scratch/rs_subtypes/adni2_subtype_20161207_min30vol/';

%% set up files_in structure
 
files_in.model = '/home/atam/scratch/rs_subtypes/adni2_model_multi_site_scanner_fd_snr_20161123.csv';
files_in.mask = '/gs/project/gsf-624-aa/database2/preventad/mask_mnc/mask.mnc';
files_in.subtype.network_0001 = [path_sub 'network_1/network_1_subtype.mat'];
files_in.subtype.network_0002 = [path_sub 'network_2/network_2_subtype.mat'];
files_in.subtype.network_0003 = [path_sub 'network_3/network_3_subtype.mat'];
files_in.subtype.network_0004 = [path_sub 'network_4/network_4_subtype.mat'];
files_in.subtype.network_0005 = [path_sub 'network_5/network_5_subtype.mat'];
files_in.subtype.network_0006 = [path_sub 'network_6/network_6_subtype.mat'];
files_in.subtype.network_0007 = [path_sub 'network_7/network_7_subtype.mat'];


%% set up files_in structure

files = dir(path_data);
files = {files.name};
n_files = length(files);

for ss = 3:n_files
    % Get the file name and path
    tmp = strsplit(files{ss},'_');
    sub_name = tmp{1};
    run_name = tmp{3};
    net_field = strcat('network_',tmp{6}(1:4));
    net_num = tmp{6};
    files_in.data.(net_field).(sub_name) = [path_data sprintf('%s_session1_%s_rmap_part_%s',sub_name,run_name,net_num)];
end
     

%% options

opt.folder_out = path_out;
opt.scale = 7;
opt.stack.regress_conf = {'age','gender','fd'};
opt.subtype.nb_subtype = 3;


%% run pipeline
[pipe,opt] = niak_pipeline_subtype(files_in,opt);