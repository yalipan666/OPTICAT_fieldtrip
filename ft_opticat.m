%% scripts to run OPTICAT with fieldtrip (MEG) data
% Usage:    >> data4ICA_training =
% ft_opticat(data4ICA,data,hdr,saccade_onset,bpfreq,saccade_epoch);
%
% Inputs:
% data4ICA - FIELDTRIP epoch structure

% mycfg.saccade_onset    = the timepoints of saccade onset column vector, n*1, unit in timepoints
% mycfg.HIPASS           = 2, Filter's passband edge (in Hz); Best results for scenes were obtained with values of 2 to 2.5 Hz. Possibly try even higher value for tasks like Reading, e.g., 3 to 4 Hz
% mycfg.OW_FACTOR        = 1, value for overweighting of SPs (1 = add spike potentials corresponding to 100% of original data length)
% mycfg.REMOVE_EPOCHMEAN = true, mean-center the appended peri-saccadic epochs? (strongly recommended)
% mycfg.MEG_SENSORS      = cell of strings, MEG/EEG channels used in this analysis.I recommend to also include EOG channels (if they were recorded against the common reference)
%
% Outputs:
%   data4ICA_training    - FIELDTRIP structure
%
% Author: Yali Pan, July, 2022, yalipan666@gmail.com
%
% This script implements the procedures from:
% Dimigen, O. (2020). Optimizing the ICA-based removal of ocular artifacts
% from free viewing EEG. NeuroImage, https://doi.org/10.1016/j.neuroimage.2019.116117
% Please cite this publication if you use/adapt this script. Thanks!

function data4ICA_training = ft_opticat(mycfg,data4ICA)
if ~isfield(mycfg,'MEG_SENSORS')
    mycfg.MEG_SENSORS = {'MEG'};
elseif ~isfield(mycfg,'REMOVE_EPOCHMEAN')
    mycfg.REMOVE_EPOCHMEAN = true;
elseif ~isfield(mycfg,'OW_FACTOR')
    mycfg.OW_FACTOR = 1;
elseif ~isfield(mycfg,'HIPASS')
    mycfg.HIPASS = 2;
elseif ~isfield(mycfg,'saccade_onset')
    error('Please input the argument saccade_onset, the time points of sacccdes onset');
elseif ~exist('data4ICA', 'var')
    error('Please input the argument data4ICA, the fieldtrip epoch structure');
end


%% step-1: high-pass filter data above hpfreq
cfg               = [];
cfg.hpfilter      = 'yes';
cfg.hpfreq        = mycfg.HIPASS;
cfg.channel       = mycfg.MEG_SENSORS;
data4ICA_training = ft_preprocessing(cfg,data4ICA);

%% step-2: overweight SP
% create event-locked epochs to overweight
SP = [];
Fs = data4ICA_training.fsample; %sampling rate
saccade_epoch = [-0.02 0.01]; % range of the saccade epoch, unit in s
for i = 1:length(saccade_onset)
    trlbegin      = saccade_onset(i)+saccade_epoch(1)*Fs;
    trlend        = saccade_onset(i)+saccade_epoch(2)*Fs-1;
    SP.trial{i}   = data4ICA_training.trial{1,1}(:,trlbegin:trlend);
end
% clear data4ICA
if mycfg.REMOVE_EPOCHMEAN
    % remove mean, baseline subtracted across whole epoch
    SP = cellfun(@(x) x-mean(x,2),SP.trial,'Uni',false);
else
    SP = SP.trial;
end

% overweight (=copy & re-append) overweight-event-locked epochs
SP = cell2mat(SP); %(chan)*(time*trl)
n_tim = length(data4ICA_training.time{1,1});
n_trl = length(data4ICA_training.time);
n_tps = n_tim*n_trl*mycfg.OW_FACTOR; % total number of timepoints in data4ICA

%value for overweighting of SPs (1 = add spike potentials corresponding to 100% of original data length)
nn = ceil(n_tps/size(SP,2)); %replicate SP data by nn times
SP = repmat(SP,1,nn);
SP = SP(:,1:n_tps);
SP = mat2cell(SP,size(SP,1),n_tim.*ones(1,n_trl));
% merger SP and data4ICA
SP_sampleinfo = [(1:n_tim:n_tim*n_trl)' (1:n_tim:n_tim*n_trl)'+n_tim-1];
SP_sampleinfo = SP_sampleinfo+data4ICA_training.sampleinfo(end,1)+n_tim-1;
data4ICA_training.sampleinfo = [data4ICA_training.sampleinfo;SP_sampleinfo];
data4ICA_training.trial = [data4ICA_training.trial SP];
SP_time = data4ICA_training.time;
tim_diff = data4ICA_training.time{1,end}(end)-SP_time{1,1}(1)+1/Fs;
SP_time = cellfun(@(x) x+tim_diff,SP_time,'Uni',false);
data4ICA_training.time = [data4ICA_training.time SP_time];
clear SP*
end
