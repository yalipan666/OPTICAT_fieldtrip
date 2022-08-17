%% scripts to run OPTICAT with fieldtrip (MEG) data

% using optimized ICA training (OPTICAT)

% This script implements the procedures from:
% Dimigen, O. (2020). Optimizing the ICA-based removal of ocular artifacts
% from free viewing EEG. NeuroImage, https://doi.org/10.1016/j.neuroimage.2019.116117
% Please cite this publication if you use/adapt this script. Thanks!

% please contact: yalipan666@gmail.com, Script version: 2022-07-27


%% Constants
HIPASS           = 2    % Filter's passband edge (in Hz)
                        % Best results for scenes were obtained with values of 2 to 2.5 Hz
                        % Possibly try even higher value for tasks like
                        % Reading, e.g., 3 to 4 Hz
OW_FACTOR        = 1    % value for overweighting of SPs (1 = add spike potentials corresponding to 100% of original data length)
REMOVE_EPOCHMEAN = true % mean-center the appended peri-saccadic epochs? (strongly recommended)
MEG_SENSORS      = {'MEG','-MEG0413'} % indices of all MEG/EEG channels (exclude any eye-tracking channels here)


%% Load your MEG/EEG dataset
% preprocessing
cfg          = [];
cfg.dataset  = 'yourMEG.fif';
cfg.channel  = MEG_SENSORS; % remove bad channels here if any
cfg.detrend  = 'yes'; % Remove slow drifts
cfg.bpfilter = 'yes';
cfg.bpfreq   = [0.5 100];
data4ICA     = ft_preprocessing(cfg);

%% load the timepoints of saccade onset
% column vector, n*1, unit in timepoints
load('saccade_onset.mat') 

%% get the training dataset for ICA
% First high pass-filter the data then overweight spike potentials
cfg                  = [];
cfg.saccade_onset    = saccade_onset;
cfg.HIPASS           = HIPASS;
cfg.OW_FACTOR        = OW_FACTOR;
cfg.REMOVE_EPOCHMEAN = REMOVE_EPOCHMEAN;
cfg.MEG_SENSORS      = MEG_SENSORS;
data4ICA_training    = ft_opticat(cfg,data4ICA);
 
% downsample data for ica
cfg               = [];
cfg.resamplefs    = 200;
cfg.detrend       = 'no';
data4ICA_training = ft_resampledata(cfg,data4ICA_training);
 
%% run ica
cfg                 = [];
cfg.method          = 'runica';
cfg.runica.maxsteps = 100;
comp_train          = ft_componentanalysis(cfg,data4ICA_training);
 
%% remove ICA
figure
cfg           = [];
cfg.component = 1:30;       % specify the component(s) that should be plotted
cfg.layout    = 'neuromag306mag.lay'; % specify the layout file that should be used for plotting
cfg.comment   = 'no';
ft_topoplotIC(cfg, comp_train)
colormap jet;

cfg            = [];
cfg.channel    = 1:15;
cfg.continuous = 'yes';
cfg.viewmode   = 'component';
cfg.layout     = 'neuromag306mag.lay';
ft_databrowser(cfg, comp_train);
colormap jet;

%%% rejecting components back to the raw data
cfg = [];
cfg.component = input('component(s) ID that needed to be removed []: ');
data = ft_rejectcomponent(cfg, comp_train, data4ICA);
 

