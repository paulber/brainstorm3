function tutorial_raw(tutorial_dir)
% TUTORIAL_RAW: Script that reproduces the results of the online tutorials "MEG median nerve (Yokogawa)".
%
% DESCRIPTION:
%     It is based on a median nerve stimulation experiment recorded at the Montreal Neurological Institute in 2011 
%     with a CTF MEG 275 system. The sample dataset contains 6 minutes of recordings at 1200Hz for one subject 
%     and includes 100 stimulations of each arm. 
%
% CORRESPONDING ONLINE TUTORIALS:
%     http://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf
%
% INPUTS: 
%     tutorial_dir: Directory where the sample_raw.zip file has been unzipped

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Author: Francois Tadel, 2013-2016


% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
AnatDir = fullfile(tutorial_dir, 'sample_raw', 'Anatomy');
RawFile = fullfile(tutorial_dir, 'sample_raw', 'Data', 'subj001_somatosensory_20111109_01_AUX-f.ds');
% Check if the folder contains the required files
if ~file_exist(RawFile)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_raw.zip.']);
end

% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialRaw';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new report
bst_report('Start');


% ===== ANATOMY =====
% Subject name
SubjectName = 'Subject01';
% Process: Import anatomy folder
bst_process('CallProcess', 'process_import_anatomy', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {AnatDir, 'FreeSurfer'}, ...
    'nvertices',   15000, ...
    'nas',         [127, 212, 123], ...
    'lpa',         [ 55, 124, 119], ...
    'rpa',         [200, 129, 114]);

% ===== LINK CONTINUOUS FILE =====
% Process: Create link to raw file
sFilesRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {RawFile, 'CTF'}, ...
    'channelreplace', 1, ...
    'channelalign',   1);
% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesRaw, [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'comment',  'MEG/MRI Registration');


% ===== REMOVE 60/180/240 Hz =====
% Process: Notch filter: 60Hz 120Hz 180Hz
sFilesClean = bst_process('CallProcess', 'process_notch', sFilesRaw, [], ...
    'freqlist',    [60, 120, 180], ...
    'sensortypes', 'MEG', ...
    'read_all',    0);

% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', [sFilesRaw, sFilesClean], [], ...
    'timewindow',  [0, 50], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'clusters',    {}, ...
    'sensortypes', 'MEG', ...
    'edit', struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));
     
% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFilesPsd, [], ...
    'target',   10, ...  % Frequency spectrum
    'modality', 1, ...   % MEG (All)
    'comment',  'Power spectrum density');


% ===== CORRECT BLINKS AND HEARTBEATS =====
% Process: Detect heartbeats
sFilesClean = bst_process('CallProcess', 'process_evt_detect_ecg', sFilesClean, [], ...
    'channelname', 'EEG057', ...
    'timewindow',  [], ...
    'eventname',   'cardiac');

% Process: Detect eye blinks
sFilesClean = bst_process('CallProcess', 'process_evt_detect_eog', sFilesClean, [], ...
    'channelname', 'EEG058', ...
    'timewindow',  [], ...
    'eventname',   'blink');

% Process: Remove simultaneous
sFilesClean = bst_process('CallProcess', 'process_evt_remove_simult', sFilesClean, [], ...
    'remove', 'cardiac', ...
    'target', 'blink', ...
    'dt',     0.25, ...
    'rename', 0);

% % Process: SSP ECG: cardiac
% sFilesClean = bst_process('CallProcess', 'process_ssp_ecg', sFilesClean, [], ...
%     'eventname',   'cardiac', ...
%     'sensortypes', 'MEG', ...
%     'usessp',       1, ...
%     'select',       []);   % Force selection of some components

% Process: SSP EOG: blink
sFilesClean = bst_process('CallProcess', 'process_ssp_eog', sFilesClean, [], ...
    'eventname',   'blink', ...
    'sensortypes', 'MEG', ...
    'usessp',       1, ...
    'select',       1);   % Force selection of some components
    
% Process: Snapshot: SSP projectors
bst_process('CallProcess', 'process_snapshot', sFilesClean, [], ...
    'target',  2, ...  % SSP projectors
    'comment', 'SSP projectors');


% ===== IMPORT EVENTS =====
% Process: Import MEG/EEG: Events
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFilesClean, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   'left, right', ...
    'timewindow',  [], ...
    'epochtime',   [-0.1, 0.3], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    [-0.1, 0]);

% Process: Add time offset: -4.20ms
sFilesEpochs = bst_process('CallProcess', 'process_timeoffset', sFilesEpochs, [], ...
    'offset',    -0.0042, ...
    'overwrite', 1);

% Process: Average: By condition (subject average)
sFilesAvg = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
    'avgtype',    6, ...  % By trial groups (subject average)
    'avg_func',   1, ...  % Arithmetic average: mean(x)
    'keepevents', 0);

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1, ...  % MEG (All)
    'comment',  'Evoked response');


% ===== SOURCE MODELING =====
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvg, [], ...
    'comment',      '', ...
    'sourcespace',  1, ...
    'meg',          3);  % Overlapping spheres

% Process: Compute noise covariance
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',     [-0.104, -0.005], ...
    'sensortypes',  'MEG, EEG', ...
    'target',       1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',     1, ...
    'identity',     0, ...
    'copycond',     0, ...
    'copysubj',     0, ...
    'replacefile',  1);  % Replace

% Process: Snapshot: Noise covariance
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',  3, ...  % Noise covariance
    'comment', 'Noise covariance');

% Process: Compute sources
sFilesSrcAvg = bst_process('CallProcess', 'process_inverse', sFilesAvg, [], ...
    'comment', '', ...
    'method',  2, ...  % dSPM
    'wmne',    struct(...
         'NoiseCov',      [], ...
         'InverseMethod', 'dspm', ...
         'ChannelTypes',  {{}}, ...
         'SNR',           3, ...
         'diagnoise',     0, ...
         'SourceOrient',  {{'fixed'}}, ...
         'loose',         0.2, ...
         'depth',         1, ...
         'weightexp',     0.5, ...
         'weightlimit',   10, ...
         'regnoise',      1, ...
         'magreg',        0.1, ...
         'gradreg',       0.1, ...
         'eegreg',        0.1, ...
         'ecogreg',       0.1, ...
         'seegreg',       0.1, ...
         'fMRI',          [], ...
         'fMRIthresh',    [], ...
         'fMRIoff',       0.1, ...
         'pca',           1), ...
    'sensortypes', 'MEG, MEG MAG, MEG GRAD, EEG', ...
    'output',      1);  % Kernel only: shared

% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesSrcAvg, [], ...
    'target',   8, ...  % Sources (one time)
    'modality', 1, ...  % MEG (All)
    'orient',   3, ...  % top
    'time',     0.035, ...
    'comment',  'Source maps at 35ms');



% Save and display report
ReportFile = bst_report('Save', sFilesSrcAvg);
bst_report('Open', ReportFile);



