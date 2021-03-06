
clear

warning('This script will generate a lot of results in the current folder. Press CTRL-C now to interrupt !')
pause

%% Set up paths
path_curr = pwd;
path_roi  = [path_curr filesep 'rois']; % Where to save the real regional time series
path_out  = [path_curr filesep 'xp_2014_11_28']; % Where to store the results of the simulation
path_logs = [path_out filesep 'logs']; % Where to save the logs of the pipeline
psom_mkdir(path_out);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Download the ICBM aging functional connectomes - time series %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~psom_exist(path_roi)
    mkdir(path_roi)
    cd(path_roi)
    fprintf('Could not find the aging time series. Downloading from figshare ...\n')
    instr_dwnld = 'wget http://downloads.figshare.com/article/public/1241650';
    [status,msg] = system(instr_dwnld);
    if status~=0
        psom_clean(path_roi)
        error('Could not download the necessary data from figshare. The command was: %s. The error message was: %s',instr_dwnld,msg);
    end
    instr_unzip = 'unzip 1241650';
    [status,msg] = system(instr_unzip);
    if status~=0
        psom_clean(path_roi)
        error('Could not unzip the necessary data. The command was: %s. The error message was: %s',instr_unzip,msg);
    end
    psom_clean('1241650');
    cd(path_curr)
end

%% Read the demographics data
[tab,list_subject,ly] = niak_read_csv([path_roi filesep 'aging_full_model.csv']);
age = tab(:,2);

%% The atoms 
[hdr,atoms] = niak_read_vol([path_roi filesep 'brain_atoms.nii.gz']);

%% Read connectoms
for ss = 1:length(list_subject)
    file_conn = [path_roi filesep 'correlation_' list_subject{ss} '_roi.mat'];
    data = load(file_conn);
    if ss == 1
        conn = zeros(length(list_subject),length(data.mat_r));
    end
    R = data.mat_r;
    R = (R-median(R))/niak_mad(R);    
    conn(ss,:) = R;
end

%% Just simple t-stats
exp = [ones(length(age),1) age];
x = exp;
x(:,2) = niak_normalize_tseries(exp(:,2));
[beta,e,std_e,ttest,pce] = niak_lse(conn,x,[0;1]);
[fdr,sig] = niak_fdr(pce','BH',0.05);
fprintf('Max ttest: %1.2f\n',max(ttest));
fprintf('Percentage of discovery: %1.2f\n',sum(sig)/length(sig));
opt_v.limits = [-0.5 0.5];
niak_visu_matrix(beta(2,:)',opt_v)

%% Now try to predict age
list_c = 2.^(-7:2:10);
list_g = 2.^(-10:2:5);
K = 30;
n = 15;
age_hat = zeros(length(list_subject),1);
%exp = exp(randperm(size(exp,1)),:);
perc = 0.4;
nb_samps_age = zeros(size(age));
nb_samps = 40;
for ss = 1:nb_samps % Leave-one out cross-validation
%for ss = 1:10 % Leave-one out cross-validation
    % Verbose progress
    niak_progress(ss,nb_samps);
    
    % Create a logical mask for the leave-one-out
    mask = false(size(age));
    mask(1:ceil(perc*length(list_subject))) = true;
    mask = mask(randperm(length(mask)));
    
    % Extract the data, excluding one subject
    y = conn(mask,:);
    x = exp(mask,:);
    
    % Run a BASC-GLM analysis
    [beta,e,std_e,ttest,pce] = niak_lse(y,x,[0;1]); 
    R = niak_build_correlation(niak_vec2mat(ttest')); % Compute the similarity matrix between effect maps
    hier = niak_hierarchical_clustering(R,struct('flag_verbose',false));
    part = niak_threshold_hierarchy(hier,struct('thresh',K));
    
    % Generate connectomes at the new resolution
    avg_conn = zeros(length(list_subject)-1,K*(K-1)/2);
    for ss2 = 1:length(list_subject)
        avg_conn(ss2,:) = niak_build_avg_sim(niak_vec2mat(conn(ss2,:)),part,true);
    end

    % Rank connections   
    [brank,erank,std_erank,ttest_rank,pce_rank] = niak_lse(avg_conn(mask,:),x,[0;1]);
    [val,order] = sort(abs(ttest_rank),'descend');
    
    % Run a stability analysis
    if ss == 1
        stab = zeros(length(part),length(part));
        stab_net = zeros(length(part),length(part));
    end
    tmp = zeros(size(ttest_rank));
    tmp(order(1:n)) = 1;
    tmp = niak_vec2mat(tmp,0);
    [indx,indy] = find(tmp);
    adj = zeros(size(stab));
    for num_i = 1:length(indx)
        adj(part==indx(num_i),part==indy(num_i)) = 1;
    end
    stab = stab + adj;
    stab_net = stab_net + niak_part2mat(part,true);
    
    % Normalize the low-resolution connectomes (not using the test data)
    avg_conn = avg_conn(:,order(1:n));
    m_avg_conn = mean(avg_conn(mask,:),1);
    s_avg_conn = std(avg_conn(mask,:),[],1);
    avg_conn = (avg_conn - ones(length(list_subject),1)*m_avg_conn)./repmat(s_avg_conn,[length(list_subject),1]);
    
    % a simple regression model
    beta_age = niak_lse(x(:,2),[ones(sum(mask),1) avg_conn(mask,:)]);
    age_hat(~mask) = age_hat(~mask) + [ones(sum(~mask),1) avg_conn(~mask,:)]*beta_age;
    nb_samps_age(~mask) = nb_samps_age(~mask)+1;
%      % a SVM prediction
%      score = zeros(length(list_c),length(list_g));
%      samp = [ones(length(list_subject)-1,1) avg_conn(mask,:)];
%      for num_c = 1:length(list_c)
%          for num_g = 1:length(list_g)
%              for ss2 = 1:(length(list_subject)-2) %% Nested cross-validation
%                  mask2 = true(length(list_subject)-1,1);
%                  mask2(ss2) = false;
%                  model_svm = svmtrain(x(mask2,2),samp(mask2,:),sprintf('-s 3 -t 2 -c %1.10f -g %1.10f',list_c(num_c),list_g(num_g)));
%                  val_pred = svmpredict(x(ss2,2),samp(ss2,:),model_svm);
%                  score(num_c,num_g) = score(num_c,num_g) + (val_pred-x(ss2,2))^2;
%               end
%               score(num_c,num_g) = sqrt(score(num_c,num_g)/(length(list_subject)-2));
%          end
%      end
%      [score_min,ind] = min(score(:));
%      [ind_c,ind_g] = ind2sub(size(score),ind);
%      model_svm = svmtrain(x(:,2),samp,sprintf('-s 3 -t 2 -c %1.10f -g %1.10f',list_c(ind_c),list_g(ind_g)));
%      age_hat(ss) = svmpredict(exp(ss,2),[1 avg_conn(ss,:)],model_svm);
end
stab = stab / nb_samps;
stab_net = stab_net / nb_samps;
hier_stab = niak_hierarchical_clustering (stab_net);
order_stab = niak_hier2order (hier_stab);
age_hat = age_hat./nb_samps_age;
niak_visu_matrix(stab(order_stab,order_stab))
figure 
niak_visu_matrix(stab_net(order_stab,order_stab))
part_stab = niak_threshold_hierarchy(hier_stab,struct('thresh',K));
niak_visu_part(part_stab(order_stab));
avg_sel = niak_build_avg_sim(stab,part_stab);
figure
niak_visu_matrix(avg_sel);
[val,order] = sort(avg_sel(:),'descend');
[x,y] = ind2sub([K K],order);
hdr.file_name = 'discriminant_networks.nii.gz';
niak_write_vol(hdr,niak_part2vol(part_stab,atoms));

for num_c = 1:20
fprintf('Network %i-%i (reliability %1.2f)\n',x(num_c),y(num_c),val(num_c))
end