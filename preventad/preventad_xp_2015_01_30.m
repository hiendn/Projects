clear

path_data = '/home/pbellec/database/preventad/scores_2015_01_28/';

%list_cov = [5 10 11 14];
list_cov = [5 9 11 14];
%list_cov = 5;

%list_net = [3 4 6 7 8 10 11];
%list_net = [3 6 7 10 11];
list_net = [3 4 6 7 8 10];
%list_net = 7;

nb_clust = 10;
pce = zeros(length(list_cov),nb_clust,length(list_net));

for ind_net = 1:length(list_net)
    num_net = list_net(ind_net);
    path_res = [path_data 'cluster_' num2str(num_net) 'R_diff' filesep];

    %% Load data
    file_stack = [path_data,'netstack_net',num2str(num_net),'.nii.gz'];
    [hdr,stab] = niak_read_vol(file_stack);
    [hdr,mask] = niak_read_vol([path_data 'mask.nii.gz']);
    tseries = niak_vol2tseries(stab,mask);

    %% correct for the mean
    tseries_ga = niak_normalize_tseries(tseries,'mean');
    
    %% Run an ica on the demeaned maps
    opt_sica.type_nb_comp = 0;
    opt_sica.param_nb_comp = nb_clust;
    res_ica = niak_sica( tseries_ga , opt_sica);
    vol_sica = niak_tseries2vol(res_ica.composantes',mask);
    weights = res_ica.poids;

    %% Load phenotypic variables
    [tab,lx,ly] = niak_read_csv([path_data 'model_preventad_20141215.csv']);
    load([path_data 'list_subject.mat']);
    tab2 = zeros(length(list_subject),size(tab,2));
    for ss = 1:length(list_subject)
        ind_s = find(ismember(lx,list_subject{ss}));
        tab2(ss,:) = tab(ss,:);
    end

    %% GLM analysis 
    for cc = 1:length(list_cov)
        covar = tab2(:,list_cov(cc));
        fd = tab2(:,15);
        age = tab2(:,1);
        sex = tab2(:,2);
        mask_covar = ~isnan(covar);
        %mask_covar = ~isnan(covar)&(tab2(:,2)~=1);
        %model_covar.x = [ones(sum(mask_covar),1) niak_normalize_tseries(covar(mask_covar),'mean').*niak_normalize_tseries(sex(mask_covar),'mean') niak_normalize_tseries([covar(mask_covar) fd(mask_covar) age(mask_covar) sex(mask_covar)],'mean')];
        model_covar.x = [ones(sum(mask_covar),1) niak_normalize_tseries([covar(mask_covar) fd(mask_covar)],'mean')];
        model_covar.y = weights(mask_covar,:);
        %model_covar.c = [0 ; 0 ; 1; 0 ; 0 ; 0];
        model_covar.c = [0 ; 1 ; 0];
        opt_glm.test = 'ttest';
        opt_glm.flag_beta = true;
        res_covar = niak_glm(model_covar,opt_glm);
        fprintf('%s\n',ly{list_cov(cc)});
        %res_covar.beta(model_covar.c>0,:)
        pce(cc,:,ind_net) = res_covar.pce;
    end
    pce(:,:,ind_net)
end

[fdr,test] = niak_fdr(pce(:),'BH',0.1);
pce
test = reshape(test,size(pce))

if 0

w_hat = model_covar.x*res_covar.beta;
plot(w_hat(:,1), model_covar.y(:,1),'.')

%% GLM analysis -- full brain
covar = tab2(:,9);
fd = tab2(:,15); 
mask_covar = ~isnan(covar)&(part~=2);
model_covar.x = [ones(sum(mask_covar),1) niak_normalize_tseries([covar(mask_covar) fd(mask_covar)],'mean')];
model_covar.y = tseries_ga(mask_covar,:);
model_covar.c = [0 ; 1 ; 0];
opt_glm.test = 'ttest';
opt_glm.flag_beta = true;
res_covar = niak_glm(model_covar,opt_glm);
res_covar.pce;
res_covar.beta(model_covar.c>0,:);
w_hat = model_covar.x*res_covar.beta;
plot(w_hat(:,2), model_covar.y(:,2),'.')

%% GLM analysis the other way
covar = tab2(:,13);
fd = tab2(:,15); 
mask_covar = ~isnan(covar);
model_covar.y = [niak_normalize_tseries(covar(mask_covar),'mean')];
model_covar.x = [ones(sum(mask_covar),1) niak_normalize_tseries(weights(mask_covar,:),'mean') fd(mask_covar)];
model_covar.c = [0 ; ones(size(weights,2),1) ; 0];
opt_glm.test = 'ftest';
opt_glm.flag_beta = true;
res_covar = niak_glm(model_covar,opt_glm);
res_covar.pce
%res_covar.beta(model_covar.c>0,:)

%% Visualize the cluster means
ind_visu = 1:max(part);
opt_vp.vol_limits = [0 1];
gd_avg = mean(stab,4);
for cc = ind_visu
    figure
    niak_montage(mean(stab(:,:,:,part==cc),4),opt_vp);
    title(sprintf('Average cluster %i',cc))
end
figure
niak_montage(gd_avg,opt_vp);
title('Grand average')

%% Visualize the cluster means, after substraction of the mean
opt_vp.vol_limits = [-0.2 0.2];
opt_vp.type_color = 'hot_cold';
ind_visu = 1:max(part);
gd_avg = mean(stab,4);
for cc = ind_visu
    figure
    niak_montage(mean(stab(:,:,:,part==cc),4)-gd_avg,opt_vp);
    title(sprintf('Average cluster %i',cc))
end

%% Write volumes
% The average per cluster
psom_mkdir(path_res)
avg_clust_raw = zeros(max(part),size(tseries,2));
for cc = 1:max(part)
    avg_clust_raw(cc,:) = mean(tseries(part==cc,:),1);
end
vol_avg_raw = niak_tseries2vol(avg_clust_raw,mask);
hdr.file_name = [path_res 'mean_clusters.nii.gz'];
niak_write_vol(hdr,vol_avg_raw);

% The demeaned, z-ified volumes
avg_clust = zeros(max(part),size(tseries,2));
for cc = 1:max(part)
    avg_clust(cc,:) = mean(tseries_ga(part==cc,:),1);
end
avg_clust = niak_normalize_tseries(avg_clust','median_mad')';
vol_avg = niak_tseries2vol(avg_clust,mask);
hdr.file_name = [path_res 'mean_cluster_demeaned.nii.gz'];
niak_write_vol(hdr,vol_avg);

hdr.file_name = [path_res 'grand_mean_clusters.nii.gz'];
niak_write_vol(hdr,mean(stab,4));

end