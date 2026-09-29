function vfUSI_StimBox_TTL_EACH_FRAME_OR_TRIGGER_ACCESSORIES_COMMAND(cfg)
% ASCII safe, MATLAB 2017b compatible
%
% Backend runner used by the GUI entry file.
%
% WHAT THIS VERSION DOES
% -------------------------------------------------------------------------
% 1) Keeps backward compatibility with the older config structure.
% 2) Supports independent enable/disable for:
%       - StimBox
%       - PulsePal
%       - Step motor
% 3) Uses explicit per-trial schedules built here and passed to the object.
% 4) Supports TRUE ABSOLUTE motor start/end positions in mm.
% 5) Uses a safe processRF bridge:
%       - the callback returns RF data unchanged
%       - scheduling side effects are handled inside the object
% 6) Reduces log spam by default.
% V18: V17 stable B-mode retained; final rendered B-mode frame can be saved after STOP.
% 7) Imaging modes: Doppler, B-Mode Live, High-Res 2D and High-Res 3D.
% 8) V7 B-Mode uses the COMPANY LIVE control (not the B-mode snapshot button).
%    It starts once, stays running until Trigger Controller STOP, and stops once.
% 9) Doppler preset (5 frames, 16 blocks, no accessories) keeps the final
%    Doppler image/volume and injects ONLY CData into the company's own display.
%    Company CLim/gamma/colormap/colorbar settings are preserved and refreshed.
% 10) Anatomy saving remains opt-in and numbered: low_res_anatomy_1, _2, ...
% 11) High-resolution anatomy viewer defaults to the supplied company transform
%     with per-slice caxis-auto behavior, avoiding black 3D slices.
%    High-res modes preserve frame-synchronized StimBox/PulsePal callbacks.
%    B-Mode Live can save the final rendered frame after STOP; frame-synchronized accessories are blocked
%    because the supplied company files do not expose a B-mode frame callback.
%
% IMPORTANT
% -------------------------------------------------------------------------
% This command file expects the updated object file:
%   vfUSI_StimBox_TTL_EACH_FRAME_OR_TRIGGER_ACCESSORIES_OBJECT.m
%
% That object must contain:
%   - frame_counter
%   - newImage(obj, rfIn) returning rfOut = rfIn

    if nargin < 1 || ~isstruct(cfg)
        error('Input cfg must be a struct.');
    end

    cfg = localApplyDefaults(cfg);
    cfg = localApplyBackwardCompatibility(cfg);
    localValidateConfig(cfg);
    [SCAN, FS] = localResolveScannerAndFileService(cfg);

    % B-Mode is a live preview path, not a frame-indexed saved acquisition.
    % Run it before opening StimBox / PulsePal / motor hardware.
    if strcmpi(localGetImagingMode(cfg), 'bmode_live')
        vfUSI_OpenfUS_UIBridge('bmode_live', SCAN, cfg);
        return;
    end

    port = [];
    pp = [];
    pulsePalConnected = false;

    motorConnection = [];
    motorAxis = [];
    motorHomeMM = NaN;
    motorPositionsAbsMM = NaN;
    motorPlan = struct('frames', [], 'targets_abs_mm', []);

    stimboxFrames = struct('d3_frames', [], 'd5_frames', [], 'd6_frames', []);
    pulsepalTriggerFrames = [];

  sessionTag = datestr(now, 'yymmdd_HHMMSS');

% -------------------------------------------------------------
% Prepare output folder once per GUI START click.
%
% In split motor mode, all slice files from this run go into:
%   Data\<save_owner>\<xp_name>\Session_001_SplitMotor
%   Data\<save_owner>\<xp_name>\Session_002_SplitMotor
%   ...
% -------------------------------------------------------------
cfg = localPrepareSplitMotorSessionFolder(cfg, sessionTag);

userStopped = false;

    try
        localGuiStatus(cfg, 'Connecting hardware...', 'notready');
if isfield(cfg, 'output_session_folder') && ~isempty(cfg.output_session_folder)
    localGuiLog(cfg, sprintf('Split motor session folder: %s', cfg.output_session_folder));
end
        % Create callback object in all cases so GUI frame updates and STOP work
        pp = vfUSI_StimBox_TTL_EACH_FRAME_OR_TRIGGER_ACCESSORIES_OBJECT([]);

        % -----------------------------------------------------------------
        % GUI callbacks and object behaviour
        % -----------------------------------------------------------------
        localSetObjPropIfExists(pp, 'total_frames', cfg.n_frames);
        localSetObjPropIfExists(pp, 'probe_type', cfg.probe_type);
        localSetObjPropIfExists(pp, 'tr_unit_s', localGetTRUnit(cfg));

        localGuiLog(cfg, sprintf('Probe type: %s | TR = nblocksImage x %.3f s = %.3f s', ...
            cfg.probe_type, localGetTRUnit(cfg), ...
            localCalcTRSec(cfg.nblocksImage, localGetTRUnit(cfg))));

        if isfield(cfg, 'gui') && isstruct(cfg.gui)
            if isfield(cfg.gui, 'frameFcn')
                localSetObjPropIfExists(pp, 'onFrameFcn', cfg.gui.frameFcn);
            end
            if isfield(cfg.gui, 'logFcn')
                localSetObjPropIfExists(pp, 'onEventFcn', cfg.gui.logFcn);
            end
            if isfield(cfg.gui, 'motorStepFcn')
                localSetObjPropIfExists(pp, 'onMotorStepFcn', cfg.gui.motorStepFcn);
            end
            if isfield(cfg.gui, 'stopRequestedFcn')
                localSetObjPropIfExists(pp, 'stopRequestedFcn', cfg.gui.stopRequestedFcn);
            end
            if isfield(cfg.gui, 'frameUpdateEvery') && ~isempty(cfg.gui.frameUpdateEvery)
                localSetObjPropIfExists(pp, 'frameUpdateEvery', cfg.gui.frameUpdateEvery);
            end
        end

        % Less noisy by default
        localSetObjPropIfExists(pp, 'verbose', false);
        localSetObjPropIfExists(pp, 'stimbox_log_each_frame', false);

        % -----------------------------------------------------------------
        % Build schedules first
        % -----------------------------------------------------------------
        stimboxFrames = localBuildStimBoxFrameSets(cfg.stimbox, cfg.n_frames);
        pulsepalTriggerFrames = localBuildPulsePalTriggerFrames(cfg.pulsepal, cfg.n_frames);

        % -----------------------------------------------------------------
        % Motor
        % -----------------------------------------------------------------
        if cfg.motor.enable
            localGuiLog(cfg, sprintf('Opening motor on %s ...', cfg.motor.com));
            [motorConnection, motorAxis, motorHomeMM] = localOpenMotor(cfg.motor.com);
            motorPositionsAbsMM = localBuildMotorPositions(motorHomeMM, cfg.motor);
            motorPlan = localBuildMotorPlan(cfg.motor, motorPositionsAbsMM, cfg.n_frames);
        else
            motorPositionsAbsMM = NaN;
            motorPlan.frames = [];
            motorPlan.targets_abs_mm = [];
        end

        % -----------------------------------------------------------------
        % StimBox
        % -----------------------------------------------------------------
        if cfg.stimbox.enable
            localGuiLog(cfg, sprintf('Opening StimBox on %s ...', cfg.stimbox.com));
            port = localOpenStimBoxPort(cfg.stimbox.com, cfg.stimbox.baud);

            localSetObjPropIfExists(pp, 'port', port);
            localSetObjPropIfExists(pp, 'stim_mode', 'stimbox');

            % Legacy fallback fields
            localSetObjPropIfExists(pp, 'd3_trig', localFramesToLegacySpec(stimboxFrames.d3_frames, cfg.n_frames));
            localSetObjPropIfExists(pp, 'd5_trig', localFramesToLegacySpec(stimboxFrames.d5_frames, cfg.n_frames));
            localSetObjPropIfExists(pp, 'd6_trig', localFramesToLegacySpec(stimboxFrames.d6_frames, cfg.n_frames));

            % New explicit frame lists
            localSetObjPropIfExists(pp, 'stimbox_enable', true);
            localSetObjPropIfExists(pp, 'stimbox_d3_frames', stimboxFrames.d3_frames);
            localSetObjPropIfExists(pp, 'stimbox_d5_frames', stimboxFrames.d5_frames);
            localSetObjPropIfExists(pp, 'stimbox_d6_frames', stimboxFrames.d6_frames);

            % Shared schedule fallback fields
            localSetObjPropIfExists(pp, 'stimbox_output_d3', cfg.stimbox.d3_enable);
            localSetObjPropIfExists(pp, 'stimbox_output_d5', cfg.stimbox.d5_enable);
            localSetObjPropIfExists(pp, 'stimbox_output_d6', cfg.stimbox.d6_enable);
            localSetObjPropIfExists(pp, 'stimbox_start_frame', cfg.stimbox.start_frame);
            localSetObjPropIfExists(pp, 'stimbox_duration_frames', cfg.stimbox.frame_duration);
            localSetObjPropIfExists(pp, 'stimbox_repeat_enable', cfg.stimbox.repeat_enable);
            localSetObjPropIfExists(pp, 'stimbox_repeat_every_frames', cfg.stimbox.repeat_interval_frames);

            % Keep object verbose off unless explicitly requested
            localSetObjPropIfExists(pp, 'verbose', logical(cfg.stimbox.verbose));

            localGuiLog(cfg, sprintf('StimBox armed on %s.', cfg.stimbox.com));
            localGuiLog(cfg, localStimBoxSummaryText(cfg, stimboxFrames));
        else
            localSetObjPropIfExists(pp, 'stimbox_enable', false);
        end

        % -----------------------------------------------------------------
        % PulsePal
        % -----------------------------------------------------------------
        if cfg.pulsepal.enable
            localGuiLog(cfg, sprintf('Opening PulsePal on %s ...', cfg.pulsepal.com));

localOpenPulsePalRobust(cfg.pulsepal.com);
pulsePalConnected = true;

if cfg.pulsepal.custom_train_id > 0
    error(['CustomTrainID > 0 is not supported yet in this GUI, ' ...
           'because no custom pulse times/voltages are uploaded with SendCustomPulseTrain.']);
end

try
    localProgramPulsePal(cfg);
catch MEpp
    localGuiLog(cfg, sprintf('PulsePal programming failed on first try, retrying: %s', MEpp.message));
    localClosePulsePalRobust();
    localKillCOMPortRobust(cfg.pulsepal.com);
    pause(0.30);
    localOpenPulsePalRobust(cfg.pulsepal.com);
    localProgramPulsePal(cfg);
end

            localGuiLog(cfg, sprintf(['PulsePal programmed: ch=%d | V1=%g V | d1=%g s | ' ...
                'IPI=%g s | train=%g s | rest=%g V | biphasic=%d'], ...
                cfg.pulsepal.channel, ...
                cfg.pulsepal.phase1_voltage, ...
                cfg.pulsepal.phase1_duration_s, ...
                cfg.pulsepal.interpulse_interval_s, ...
                cfg.pulsepal.train_duration_s, ...
                cfg.pulsepal.resting_voltage, ...
                logical(cfg.pulsepal.is_biphasic)));

            localSetObjPropIfExists(pp, 'pulsepal_enable', true);
            localSetObjPropIfExists(pp, 'pulsepal_start', localFramesToLegacyPulsePalStart(pulsepalTriggerFrames));
            localSetObjPropIfExists(pp, 'pulsepal_channel', cfg.pulsepal.channel);
            localSetObjPropIfExists(pp, 'pulsepal_duration', cfg.pulsepal.train_duration_s);
            localSetObjPropIfExists(pp, 'pulsepal_com', cfg.pulsepal.com);
            localSetObjPropIfExists(pp, 'pulsepal_verbose', true);
            localSetObjPropIfExists(pp, 'pulsepal_trigger_frames', pulsepalTriggerFrames);

            if cfg.stimbox.enable
                localSetObjPropIfExists(pp, 'stim_mode', 'hybrid');
            else
                localSetObjPropIfExists(pp, 'stim_mode', 'pulsepal');
            end

            localGuiLog(cfg, sprintf('PulsePal armed on %s, channel %d.', ...
                cfg.pulsepal.com, cfg.pulsepal.channel));
            localGuiLog(cfg, localPulsePalSummaryText(cfg, pulsepalTriggerFrames));
        else
            localSetObjPropIfExists(pp, 'pulsepal_enable', false);
        end

        if ~cfg.stimbox.enable && ~cfg.pulsepal.enable
            localGuiLog(cfg, 'No stimulation device selected.');
            localSetObjPropIfExists(pp, 'stim_mode', 'none');
        elseif cfg.stimbox.enable && cfg.pulsepal.enable
            localGuiLog(cfg, 'StimBox and PulsePal both enabled.');
            localSetObjPropIfExists(pp, 'stim_mode', 'hybrid');
        end

% -------------------------------------------------------------
% Motor callback behavior depends on acquisition mode.
%
% Split mode:
%   motor moves before SCAN.doppler
%   no motor callback
%
% Continuous mode:
%   one long MAT
%   motor moves inside processRF callback
% -------------------------------------------------------------
if cfg.motor.enable && strcmpi(localGetMotorAcqMode(cfg), 'continuous')

    continuousMotorPlan = localBuildContinuousMotorCallbackPlan( ...
        cfg.motor, motorPositionsAbsMM, cfg.n_frames);

    localSetObjPropIfExists(pp, 'motor_enable', true);
    localSetObjPropIfExists(pp, 'motor_axis', motorAxis);
    localSetObjPropIfExists(pp, 'motor_settle_pause_s', cfg.motor.settle_pause_s);

    % Do not block the frame callback while the stage travels.
    localSetObjPropIfExists(pp, 'motor_wait_until_idle', ...
        logical(cfg.motor.wait_until_idle_in_scan));

    localSetObjPropIfExists(pp, 'motor_use_explicit_plan', true);
    localSetObjPropIfExists(pp, 'motor_move_frames', continuousMotorPlan.frames);
    localSetObjPropIfExists(pp, 'motor_move_target_abs_mm', continuousMotorPlan.targets_abs_mm);
    localSetObjPropIfExists(pp, 'motor_display_total', numel(continuousMotorPlan.frames));

    localGuiLog(cfg, sprintf( ...
        'Continuous motor mode armed: %d in-scan motor moves planned.', ...
        numel(continuousMotorPlan.frames)));

else

    localSetObjPropIfExists(pp, 'motor_enable', false);
    localSetObjPropIfExists(pp, 'motor_axis', []);
    localSetObjPropIfExists(pp, 'motor_use_explicit_plan', false);
    localSetObjPropIfExists(pp, 'motor_move_frames', []);
    localSetObjPropIfExists(pp, 'motor_move_target_abs_mm', []);
    localSetObjPropIfExists(pp, 'motor_display_total', 0);

end

       % -----------------------------------------------------------------
% Main acquisition loop: STABLE SYNCHRONIZED MOTOR MODE
%
% Important:
%   - motor moves BEFORE SCAN.doppler
%   - motor settles BEFORE SCAN.doppler
%   - motor does NOT move during SCAN.doppler
%
% One motor position = one complete saved acquisition.
% -----------------------------------------------------------------

if cfg.motor.enable && ~isempty(motorPositionsAbsMM) && all(~isnan(motorPositionsAbsMM))
    scanMotorPositionsAbsMM = motorPositionsAbsMM(:)';
else
    scanMotorPositionsAbsMM = NaN;
end

motorIsValid = cfg.motor.enable && ...
    ~isempty(scanMotorPositionsAbsMM) && ...
    all(~isnan(scanMotorPositionsAbsMM));

if motorIsValid
    nMotorPositionsThisRun = numel(scanMotorPositionsAbsMM);
else
    nMotorPositionsThisRun = 1;
end

motorAcqMode = 'off';
if cfg.motor.enable && isfield(cfg.motor, 'acquisition_mode')
    motorAcqMode = cfg.motor.acquisition_mode;
end

isSplitMotor = motorIsValid && strcmpi(motorAcqMode, 'split');
isContinuousMotor = motorIsValid && strcmpi(motorAcqMode, 'continuous');

% Split mode:
%   one SCAN.doppler call per slice block.
%   Keep cycling through slices until cfg.n_frames total requested frames
%   are reached.
%
% Example:
%   cfg.n_frames = 125
%   cfg.motor.frames_per_position = 25
%   nMotorPositionsThisRun = 3
%
%   nSplitBlocksPerTrial = ceil(125 / 25) = 5
%   sequence:
%       block 1 -> slice 1, t001
%       block 2 -> slice 2, t001
%       block 3 -> slice 3, t001
%       block 4 -> slice 1, t002
%       block 5 -> slice 2, t002

if isSplitMotor
    framesPerSplitBlock = max(1, round(cfg.motor.frames_per_position));
    nSplitBlocksPerTrial = ceil(cfg.n_frames / framesPerSplitBlock);
    nMotorLoopThisRun = nSplitBlocksPerTrial;

    if mod(nSplitBlocksPerTrial, nMotorPositionsThisRun) ~= 0
        localGuiLog(cfg, sprintf([ ...
            'SPLIT MOTOR WARNING: total frames do not form complete slice cycles. ' ...
            'Frames/trial=%d, frames/slice=%d, slices=%d. ' ...
            'For clean motor reconstruction, prefer Frames/trial = slices x frames/slice x cycles.'], ...
            cfg.n_frames, framesPerSplitBlock, nMotorPositionsThisRun));
    end
else
    framesPerSplitBlock = cfg.n_frames;
    nSplitBlocksPerTrial = 1;
    nMotorLoopThisRun = 1;
end

totalAcqCount = cfg.n_trials * nMotorLoopThisRun;
acqCounter = 0;

% Split motor: do not write TXT/JOURNAL after every small MAT file.
% Store lightweight info and write ONE summary TXT at the very end.
splitSessionRows = {};
splitLastNameFile = '';
splitLastMd = struct();
splitLastTrial = NaN;

% -------------------------------------------------------------------------
% FAST SLICE PIPELINE STATE
%
% When a move to the next slice has already been issued (during the save of
% the previous slice), motorPrefetchTargetMM holds that target. The next
% iteration then only has to wait for the stage to report idle instead of
% issuing the move from scratch.
%
% NaN means "no move is in flight".
% -------------------------------------------------------------------------
motorPrefetchTargetMM = NaN;
useFastMotorPipeline = isSplitMotor && logical(cfg.motor.fast_pipeline);

if useFastMotorPipeline
    localGuiLog(cfg, ...
        'Fast slice pipeline ON: next slice move overlaps the current file save.');
end

for iTrial = 1:cfg.n_trials

    for iMotor = 1:nMotorLoopThisRun

        acqCounter = acqCounter + 1;
   
        % -------------------------------------------------------------
        % Split mode block indexing
        %
        % iMotor is now the split block number, not always the slice number.
        % Convert block number into:
        %   iSliceIndex = physical motor slice
        %   iTimeIndex  = repeated time/cycle index
        % -------------------------------------------------------------
        if isSplitMotor
            iSliceIndex = mod(iMotor - 1, nMotorPositionsThisRun) + 1;
            iTimeIndex  = floor((iMotor - 1) / nMotorPositionsThisRun) + 1;
        else
            iSliceIndex = iMotor;
            iTimeIndex  = iTrial;
        end
        if localStopRequested(cfg)
            error('vfUSI:UserStop', 'User stop requested.');
        end

        localGuiFrame(cfg, 0);
        localGuiTrial(cfg, acqCounter, totalAcqCount);

        requestedMotorAbsMM = NaN;
        actualMotorAbsMM = NaN;

              % -------------------------------------------------------------
        % Motor movement before acquisition
        %
        % Split mode:
        %   move to every slice before each SCAN.doppler call.
        %
        % Continuous mode:
        %   move to the first slice before SCAN.doppler starts.
        %   later moves happen inside processRF callback.
        % -------------------------------------------------------------
 if isSplitMotor

    requestedMotorAbsMM = scanMotorPositionsAbsMM(iSliceIndex);

    % ---------------------------------------------------------
    % If the move to this slice was already issued while the
    % previous file was being saved, the stage has been travelling
    % during that time. Only the remaining travel is waited on here,
    % so acquisition starts essentially the moment the stage lands.
    % ---------------------------------------------------------
    if useFastMotorPipeline && ~isnan(motorPrefetchTargetMM) && ...
            abs(motorPrefetchTargetMM - requestedMotorAbsMM) < 1e-9

        actualMotorAbsMM = localFinishMotorMove(cfg, motorAxis, requestedMotorAbsMM);

    else
        localGuiStatus(cfg, sprintf( ...
            'Split mode: moving motor slice %d/%d, t%03d before acquisition...', ...
            iSliceIndex, nMotorPositionsThisRun, iTimeIndex), 'notready');

        [actualMotorAbsMM, ~] = localMoveMotorBeforeStableScan( ...
            cfg, motorAxis, requestedMotorAbsMM, iSliceIndex, nMotorPositionsThisRun);
    end

    motorPrefetchTargetMM = NaN;

    localGuiMotor(cfg, iSliceIndex, nMotorPositionsThisRun, actualMotorAbsMM, 0);

        elseif isContinuousMotor

            requestedMotorAbsMM = scanMotorPositionsAbsMM(1);

            localGuiStatus(cfg, sprintf( ...
                'Continuous mode: moving motor to first slice before acquisition...'), ...
                'notready');

            [actualMotorAbsMM, ~] = localMoveMotorBeforeStableScan( ...
                cfg, motorAxis, requestedMotorAbsMM, 1, nMotorPositionsThisRun);

            localGuiMotor(cfg, 1, nMotorPositionsThisRun, actualMotorAbsMM, 0);
        end
        scanTrialWord='Scan';
        try
            if isfield(cfg,'motor') && isstruct(cfg.motor) && logical(cfg.motor.enable) && ...
                    isfield(cfg.motor,'mode') && strcmpi(cfg.motor.mode,'stepped')
                scanTrialWord='Trial';
            end
        catch
        end
        runMsg = sprintf('Running acquisition %d/%d | %s %d/%d', ...
            acqCounter, totalAcqCount, scanTrialWord, iTrial, cfg.n_trials);

        if cfg.motor.enable
            runMsg = sprintf('%s | Stable motor %d/%d | abs %.3f mm', ...
                runMsg, iMotor, nMotorPositionsThisRun, requestedMotorAbsMM);
        end

        localGuiStatus(cfg, runMsg, 'notready');
        localGuiLog(cfg, runMsg);

        fprintf('----- Acquisition %02d / %02d -----\n', acqCounter, totalAcqCount);
        fprintf('----- %s %02d / %02d -----\n', scanTrialWord, iTrial, cfg.n_trials);

        if cfg.motor.enable
            fprintf('----- Stable motor position %02d / %02d: requested %.3f mm, actual %.3f mm -----\n', ...
                iMotor, nMotorPositionsThisRun, requestedMotorAbsMM, actualMotorAbsMM);
        end

                tTrial = tic;

        % -------------------------------------------------------------
        % Decide how many frames THIS SCAN.doppler call acquires.
        %
        % Split mode:
        %   each slice file gets cfg.motor.frames_per_position frames.
        %
        % Continuous mode / no motor:
        %   one full acquisition gets cfg.n_frames frames.
        % -------------------------------------------------------------
  nFramesThisAcq = cfg.n_frames;

if isSplitMotor
    framesAlreadyRequested = (iMotor - 1) * framesPerSplitBlock;
    framesRemaining = cfg.n_frames - framesAlreadyRequested;

    nFramesThisAcq = min(framesPerSplitBlock, framesRemaining);
end

        if isempty(nFramesThisAcq) || ~isnumeric(nFramesThisAcq) || ...
                isnan(nFramesThisAcq) || nFramesThisAcq < 1
            error('Invalid number of frames for this acquisition.');
        end

        nFramesThisAcq = round(nFramesThisAcq);

        % The callback object must know the frame count of THIS acquisition.
        localSetObjPropIfExists(pp, 'total_frames', nFramesThisAcq);
        % HUMOR_SPLIT_TRIGGER_LOCALIZATION_V2
        % Convert full-trial trigger frames into local frames for this SCAN.doppler call.
        try
            if isSplitMotor
                globalFrameOffsetThisAcq = (iMotor - 1) * framesPerSplitBlock;
            else
                globalFrameOffsetThisAcq = 0;
            end

            stimboxFramesThisAcq = localShiftStimBoxFramesToCurrentAcq( ...
                stimboxFrames, globalFrameOffsetThisAcq, nFramesThisAcq);

            pulsepalTriggerFramesThisAcq = localShiftFrameVectorToCurrentAcq( ...
                pulsepalTriggerFrames, globalFrameOffsetThisAcq, nFramesThisAcq);

            localSetObjPropIfExists(pp, 'stimbox_enable', logical(cfg.stimbox.enable));
            localSetObjPropIfExists(pp, 'stimbox_d3_frames', stimboxFramesThisAcq.d3_frames);
            localSetObjPropIfExists(pp, 'stimbox_d5_frames', stimboxFramesThisAcq.d5_frames);
            localSetObjPropIfExists(pp, 'stimbox_d6_frames', stimboxFramesThisAcq.d6_frames);
            localSetObjPropIfExists(pp, 'd3_trig', localFramesToLegacySpec(stimboxFramesThisAcq.d3_frames, nFramesThisAcq));
            localSetObjPropIfExists(pp, 'd5_trig', localFramesToLegacySpec(stimboxFramesThisAcq.d5_frames, nFramesThisAcq));
            localSetObjPropIfExists(pp, 'd6_trig', localFramesToLegacySpec(stimboxFramesThisAcq.d6_frames, nFramesThisAcq));

            % Disable shared fallback schedule after explicit local-frame conversion.
            localSetObjPropIfExists(pp, 'stimbox_fire_frames', []);
            localSetObjPropIfExists(pp, 'stimbox_start_frame', NaN);
            localSetObjPropIfExists(pp, 'stimbox_repeat_enable', false);
            localSetObjPropIfExists(pp, 'stimbox_output_d3', false);
            localSetObjPropIfExists(pp, 'stimbox_output_d5', false);
            localSetObjPropIfExists(pp, 'stimbox_output_d6', false);

            localSetObjPropIfExists(pp, 'pulsepal_enable', logical(cfg.pulsepal.enable));
            localSetObjPropIfExists(pp, 'pulsepal_trigger_frames', pulsepalTriggerFramesThisAcq);
            localSetObjPropIfExists(pp, 'pulsepal_fire_frames', pulsepalTriggerFramesThisAcq);
            localSetObjPropIfExists(pp, 'pulsepal_start', NaN);

            if logical(cfg.stimbox.enable) && logical(cfg.stimbox.verbose)
                msgLocal = ['StimBox local frames this acquisition: D3=' num2str(numel(stimboxFramesThisAcq.d3_frames)) ...
                    ' | D5=' num2str(numel(stimboxFramesThisAcq.d5_frames)) ...
                    ' | D6=' num2str(numel(stimboxFramesThisAcq.d6_frames)) ...
                    ' | global offset=' num2str(globalFrameOffsetThisAcq)];
                localGuiLog(cfg, msgLocal);
            end
        catch MEtrigLocal
            localGuiLog(cfg, ['Trigger localization warning: ' MEtrigLocal.message]);
        end

        try
            pp.prepareTrial();
        catch
        end

   try
    acqStartDatenum = now;

    [I, md, actualFrames, acqElapsedSec, requestedDtSec, actualMeanDtSec] = ...
        localRunSelectedAcquisition(SCAN, pp, cfg, nFramesThisAcq);

    acqEndDatenum = now;

    % V5 low-resolution anatomy preset:
    % The company GUI's live/single-image display is effectively the latest
    % completed Doppler image. Averaging the five quick images (V4) can blur
    % fine anatomy if the animal/probe moves even slightly. Therefore keep
    % the LAST frame/volume from the 5 x 16 preset, display that exact static
    % anatomy in the company GUI, and ask about saving later.
    if localIsLowResAnatomyPreset(cfg)
        try
            vendorNativeDisplay = isstruct(md) && isfield(md,'vendor_native_display') && ...
                logical(md.vendor_native_display);
            suppressLegacyDisplay = isstruct(md) && isfield(md,'suppress_legacy_display_override') && ...
                logical(md.suppress_legacy_display_override);
            if vendorNativeDisplay || suppressLegacyDisplay
                % The company callback has already produced the correct image
                % in its own axes. Do not touch CData, CLim, colormap, gamma,
                % colorbar or run our legacy preview transform again.
                md.low_res_anatomy_saved_size = size(I);
                md.low_res_anatomy_source_frames = nFramesThisAcq;
                md.low_res_anatomy_method = 'native_company_display_capture';
                localGuiLog(cfg, 'Low-res anatomy is already displayed by the native company Doppler pipeline; no display override applied.');
            else
                rawSizeBeforeAnatomyPick = size(I);
                I = localReduceDopplerToStaticAnatomy(I, cfg);
                md.low_res_anatomy_source_size = rawSizeBeforeAnatomyPick;
                md.low_res_anatomy_saved_size = size(I);
                md.low_res_anatomy_source_frames = nFramesThisAcq;
                md.low_res_anatomy_method = 'last_frame_or_volume_fallback';
                localGuiLog(cfg, sprintf( ...
                    'Low-res anatomy fallback: displaying the last of %d Doppler images/volumes.', ...
                    nFramesThisAcq));
                localShowDopplerSingleImagePreview(I, cfg, md);
            end
            % Mirror the anatomy into our own GUI.  The native OpenfUS display
            % remains untouched; these are independent display-only controls.
            localGuiPreview(cfg,I,'doppler',md);
        catch MElow
            localGuiLog(cfg, ['Low-res anatomy display preparation warning: ' MElow.message]);
        end
    end

catch ME
    localGuiLog(cfg, sprintf('ACQUISITION FAILURE: %s', ME.message));
    fprintf(2, '\n===== ACQUISITION FAILURE =====\n');
    fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'on'));
    rethrow(ME);
end

        % -------------------------------------------------------------
        % FAST SLICE PIPELINE
        %
        % The scan for this slice is finished and the data is in memory.
        % Issue the move to the NEXT slice right now, without waiting for
        % it, so the stage travels while the metadata is assembled and the
        % MAT file is written. The next iteration only waits for whatever
        % travel time is left.
        %
        % Only within-trial moves are prefetched. At a trial boundary the
        % configured inter-trial pause applies anyway.
        % -------------------------------------------------------------
        if useFastMotorPipeline && (iMotor < nMotorLoopThisRun)
            try
                nextBlockIndex = iMotor + 1;
                nextSliceIndex = mod(nextBlockIndex - 1, nMotorPositionsThisRun) + 1;
                nextTargetAbsMM = scanMotorPositionsAbsMM(nextSliceIndex);

                if localStartMotorMoveAsync(cfg, motorAxis, nextTargetAbsMM)
                    motorPrefetchTargetMM = nextTargetAbsMM;
                else
                    % Asynchronous move unsupported on this Zaber build.
                    % The next iteration performs a normal blocking move.
                    motorPrefetchTargetMM = NaN;
                end
            catch MEpre
                motorPrefetchTargetMM = NaN;
                localGuiLog(cfg, sprintf('Motor prefetch warning: %s', MEpre.message));
            end
        end

          % -------------------------------------------------------------
        % Add acquisition + motor metadata
        % -------------------------------------------------------------
        try
            % Keep motor acquisition_mode backward compatible, and add a
            % separate imaging_mode so downstream code can distinguish
            % Doppler from reconstructed high-resolution images.
            md.acquisition_mode = 'normal';
            if cfg.motor.enable
                md.acquisition_mode = cfg.motor.acquisition_mode;
            end
            md.imaging_mode = localGetImagingMode(cfg);

            % High-resolution reconstructions are saved as anatomical
            % underlays. Keep scanner-native metadata.imageType compatible
            % with the company format, while storing the anatomy role in the
            % acquisition sidecar (and filename) for deConfUSIon.
            if strcmpi(md.imaging_mode, 'highres2d') || strcmpi(md.imaging_mode, 'highres3d')
                md.image_role = 'anatomy';
                md.is_anatomy = true;
                md.anatomy_highres = true;
                md.anatomy_lowres = false;
                if strcmpi(md.imaging_mode, 'highres3d')
                    md.anatomy_dimension = '3D';
                else
                    md.anatomy_dimension = '2D';
                end
                md.anatomy_loader_hint = [ ...
                    'Static high-resolution anatomy saved as I + metadata + events; ' ...
                    'use I directly as anatomical underlay.'];
            elseif localIsLowResAnatomyPreset(cfg)
                md.image_role = 'anatomy';
                md.is_anatomy = true;
                md.anatomy_highres = false;
                md.anatomy_lowres = true;
                if localIs3DProbe(cfg)
                    md.anatomy_dimension = '3D';
                else
                    md.anatomy_dimension = '2D';
                end
                md.anatomy_loader_hint = [ ...
                    'Static low-resolution Doppler anatomy (last of 5 images/volumes; no averaging blur) ' ...
                    'saved as I + metadata + events.'];
            else
                md.image_role = 'functional';
                md.is_anatomy = false;
                md.anatomy_highres = false;
                md.anatomy_lowres = false;
                md.functional_timeseries = strcmpi(md.imaging_mode, 'functional');
                if md.functional_timeseries
                    md.functional_loader_hint = [ ...
                        'Full fUSI Doppler time series. Keep the final dimension as time; ' ...
                        'do not collapse to static anatomy.'];
                end
            end

            md.requested_frames_this_file = nFramesThisAcq;

            % Probe bookkeeping, so downstream analysis can reconstruct TR
            % without guessing which probe was used.
            md.probe_type = cfg.probe_type;
            md.tr_unit_s = localGetTRUnit(cfg);
            md.nblocksImage = cfg.nblocksImage;
            md.data_size = size(I);
            md.data_ndims = numel(size(I));
            md.is_volumetric = localIs3DProbe(cfg);

            % -------------------------------------------------------------
            % EXPLICIT GEOMETRY
            % -------------------------------------------------------------
            szI = size(I);
            md.geom_data_size = szI;
            imagingMode = localGetImagingMode(cfg);

            if strcmpi(imagingMode, 'highres2d')
                % highResAcq2D returns one reconstructed static image [Z X].
                md.geom_dim_order = '[depth_z, width_x]';
                md.geom_time_dim = NaN;
                md.geom_n_time_frames = 1;
                md.geom_slice_dim = NaN;
                md.geom_n_depth_z = szI(1);
                md.geom_n_width_x = szI(min(2, numel(szI)));
                md.geom_n_slices = 1;
                md.highres_source_frames = actualFrames;

            elseif strcmpi(imagingMode, 'highres3d')
                % highResAcq3D returns one reconstructed static volume [Z X Y].
                md.geom_dim_order = '[depth_z, width_x, slice_y]';
                md.geom_time_dim = NaN;
                md.geom_n_time_frames = 1;
                md.geom_slice_dim = 3;
                md.geom_n_depth_z = szI(1);
                md.geom_n_width_x = szI(min(2, numel(szI)));
                if numel(szI) >= 3
                    md.geom_n_slices = szI(3);
                else
                    md.geom_n_slices = 1;
                end
                md.highres_source_frames = actualFrames;

            elseif localIsLowResAnatomyPreset(cfg)
                % Static low-resolution anatomy made from the 5-frame/16-block
                % Doppler preset.
                md.geom_time_dim = NaN;
                md.geom_n_time_frames = 1;
                if numel(szI) >= 3 && localIs3DProbe(cfg)
                    md.geom_dim_order = '[depth_z, width_x, slice_y]';
                    md.geom_slice_dim = 3;
                    md.geom_n_depth_z = szI(1);
                    md.geom_n_width_x = szI(2);
                    md.geom_n_slices = szI(3);
                else
                    md.geom_dim_order = '[depth_z, width_x]';
                    md.geom_slice_dim = NaN;
                    md.geom_n_depth_z = szI(1);
                    if numel(szI) >= 2
                        md.geom_n_width_x = szI(2);
                    else
                        md.geom_n_width_x = NaN;
                    end
                    md.geom_n_slices = 1;
                end

            else
                % Standard / explicit functional Doppler time series.
                md.geom_time_dim = numel(szI);
                md.geom_n_time_frames = szI(end);

                if numel(szI) >= 4
                    md.geom_dim_order = '[depth_z, width_x, slice_y, time]';
                    md.geom_slice_dim = 3;
                    md.geom_n_depth_z = szI(1);
                    md.geom_n_width_x = szI(2);
                    md.geom_n_slices  = szI(3);
                else
                    md.geom_dim_order = '[depth_z, width_x, time]';
                    md.geom_slice_dim = NaN;
                    md.geom_n_depth_z = szI(1);
                    if numel(szI) >= 2
                        md.geom_n_width_x = szI(2);
                    else
                        md.geom_n_width_x = NaN;
                    end
                    md.geom_n_slices = 1;
                end
            end

            md.acq_start_datenum = acqStartDatenum;
            md.acq_end_datenum = acqEndDatenum;
            md.acq_start_time_string = datestr(acqStartDatenum, 'yyyy-mm-dd HH:MM:SS.FFF');
            md.acq_end_time_string = datestr(acqEndDatenum, 'yyyy-mm-dd HH:MM:SS.FFF');

            md.motor_enabled = logical(cfg.motor.enable);
            md.motor_acquisition_mode = motorAcqMode;

            md.motor_split_mode = logical(isSplitMotor);
            md.motor_continuous_mode = logical(isContinuousMotor);

            md.motor_moves_during_acquisition = logical(isContinuousMotor);
            md.motor_moves_between_acquisitions = logical(isSplitMotor);

            md.motor_stable_acquisition = logical(isSplitMotor);
            md.motor_frames_per_slice_requested = cfg.motor.frames_per_position;md.motor_time_index = iTimeIndex;
md.motor_slice_index = iSliceIndex;
md.motor_slice_count = nMotorPositionsThisRun;

md.timeIndex = iTimeIndex;
md.sliceIndex = iSliceIndex;

md.motor_index = iSliceIndex;
md.motor_n_positions = nMotorPositionsThisRun;
            md.motor_requested_abs_mm = requestedMotorAbsMM;
            md.motor_actual_abs_mm = actualMotorAbsMM;
            md.motor_home_abs_mm = motorHomeMM;

            if ~isnan(requestedMotorAbsMM) && ~isnan(motorHomeMM)
                md.motor_requested_rel_mm = requestedMotorAbsMM - motorHomeMM;
            else
                md.motor_requested_rel_mm = NaN;
            end

            if ~isnan(actualMotorAbsMM) && ~isnan(motorHomeMM)
                md.motor_actual_rel_mm = actualMotorAbsMM - motorHomeMM;
            else
                md.motor_actual_rel_mm = NaN;
            end

            md.motor_settle_pause_s = cfg.motor.settle_pause_s;

            if isSplitMotor
                md.motor_rebuild_hint = 'Split mode: sort files by motor_time_index, then motor_slice_index.';
            elseif isContinuousMotor
                md.motor_rebuild_hint = 'Continuous mode: one file contains all motor positions; use frames_per_position and motor plan.';
            else
                md.motor_rebuild_hint = 'No motor reconstruction needed.';
            end

            md.metadata_complete = true;

        catch MEmeta
            % -------------------------------------------------------------
            % This block used to swallow errors silently. If any assignment
            % above failed, md was left HALF-WRITTEN: the fields before the
            % failure were present, the ones after were missing or stale
            % from the scanner. That is exactly how mismatched geometry gets
            % saved without any visible error.
            %
            % md is now explicitly marked incomplete and the failure is
            % reported, so a bad file is obvious at acquisition time rather
            % than during analysis.
            % -------------------------------------------------------------
            try
                md.metadata_complete = false;
                md.metadata_error = MEmeta.message;
            catch
            end

            localGuiLog(cfg, sprintf( ...
                'WARNING: metadata block failed (%s). Saved metadata may be incomplete.', ...
                MEmeta.message));
        end
        
        % -------------------------------------------------------------
        % V13 ANATOMY REVIEW / DEFERRED SAVE
        % -------------------------------------------------------------
        % Normal functional/time-series scans still save automatically.
        % Low-res Doppler anatomy is mirrored into the Trigger Controller and
        % is saved only when the user presses SAVE LOW-RES.
        % High-res anatomy opens its dedicated viewer and is saved only when
        % SAVE ANATOMY is pressed there.  No Yes/No popup is used.
        imagingModeForSave = localGetImagingMode(cfg);
        isHighResAnatomy = strcmpi(imagingModeForSave,'highres2d') || ...
            strcmpi(imagingModeForSave,'highres3d');
        isLowResAnatomy = localIsLowResAnatomyPreset(cfg);
        isAnatomyAcq = isLowResAnatomy || isHighResAnatomy;
        hAnatomyViewer = [];

        if isHighResAnatomy
            try
                if strcmpi(imagingModeForSave,'highres3d')
                    hAnatomyViewer = vfUSI_HighResAnatomyViewer(I,cfg,'High-Res 3D','',md);
                else
                    hAnatomyViewer = vfUSI_HighResAnatomyViewer(I,cfg,'High-Res 2D','',md);
                end
                localGuiLog(cfg,'High-res anatomy reconstructed. Review it in the HR viewer and press SAVE ANATOMY there if wanted.');
            catch MEview
                localGuiLog(cfg,['High-res viewer warning: ' MEview.message]);
            end
        elseif isLowResAnatomy
            localGuiLog(cfg,'Low-res anatomy ready in Trigger Controller. Press SAVE LOW-RES if you want to keep it.');
        end

        saveThisAcq = ~isAnatomyAcq;

        nameFile = '';
        nameShort = '';

        if saveThisAcq
            [nameFile, nameShort] = localMakeSaveName(FS, cfg, sessionTag, ...
                motorPositionsAbsMM, motorHomeMM, iTrial);

            if cfg.motor.enable
                if isSplitMotor
                    [nameFile, nameShort] = localAppendSplitSliceToSaveName( ...
                        nameFile, iTimeIndex, iSliceIndex, nMotorPositionsThisRun, ...
                        requestedMotorAbsMM, motorHomeMM);
                elseif isContinuousMotor
                    [nameFile, nameShort] = localAppendContinuousMotorToSaveName( ...
                        nameFile, nMotorPositionsThisRun, cfg.motor.frames_per_position, ...
                        scanMotorPositionsAbsMM(1), scanMotorPositionsAbsMM(end), motorHomeMM);
                else
                    [nameFile, nameShort] = localAppendMotorPositionToSaveName( ...
                        nameFile, cfg, requestedMotorAbsMM, motorHomeMM, iMotor, iTimeIndex);
                end
            end

            [nameFile, nameShort] = localMakeFileNameUnique(nameFile);
            infoI = whos('I');
            localGuiLog(cfg, sprintf('Saving I: class=%s | size=%s | %.2f MB', ...
                infoI.class, mat2str(size(I)), infoI.bytes/1024/1024));

            if isSplitMotor
                localFastSaveMat(nameFile, I, md, cfg);
            else
                localReliableSaveMat(nameFile, I, md, cfg);
            end

            if ~isSplitMotor
                localWriteScanInfoText(nameFile, cfg, iTrial, md);
            end

            if isSplitMotor
                splitLastNameFile = nameFile;
                splitLastMd = md;
                splitLastTrial = iTrial;
                splitSessionRows{end+1} = sprintf( ...
                    'File=%s | Trial=%d | T=%03d | Slice=%03d/%03d | Frames=%d | ReqAbs=%.3f | ActAbs=%.3f', ...
                    nameShort, iTrial, iTimeIndex, iSliceIndex, nMotorPositionsThisRun, ...
                    nFramesThisAcq, requestedMotorAbsMM, actualMotorAbsMM); %#ok<AGROW>
            end

            journalTxt = localMakeJournalText(nameShort, cfg, motorPositionsAbsMM, motorHomeMM, iTrial);
            if isfield(cfg, 'output_session_name') && ~isempty(cfg.output_session_name)
                journalTxt = sprintf('%s | OutputSession=%s', journalTxt, cfg.output_session_name);
            end
            if cfg.motor.enable
                if isSplitMotor
                    journalTxt = sprintf('%s | MotorMode=SPLIT | T=%03d | Slice=%d/%d | FramesThisFile=%d | ReqAbs=%.3f mm | ActAbs=%.3f mm | MotorNotMovingDuringAcq=1', ...
                        journalTxt, iTimeIndex, iSliceIndex, nMotorPositionsThisRun, ...
                        nFramesThisAcq, requestedMotorAbsMM, actualMotorAbsMM);
                elseif isContinuousMotor
                    journalTxt = sprintf('%s | MotorMode=CONTINUOUS | Slices=%d | FramesPerSlice=%d | FramesThisFile=%d | MotorMovesDuringAcq=1', ...
                        journalTxt, nMotorPositionsThisRun, round(cfg.motor.frames_per_position), nFramesThisAcq);
                else
                    journalTxt = sprintf('%s | MotorMode=UNKNOWN | FramesThisFile=%d', ...
                        journalTxt, nFramesThisAcq);
                end
            end

            if ~isSplitMotor
                try
                    FS.writeJournal(journalTxt);
                catch MEj
                    localGuiLog(cfg, sprintf('Journal write warning: %s', MEj.message));
                end
            end

            localGuiLog(cfg, sprintf('Saved file: %s', nameFile));
            localGuiLog(cfg, sprintf('Saved folder: %s', fileparts(nameFile)));
        else
            if isHighResAnatomy
                localGuiLog(cfg,'High-res anatomy not auto-saved. Viewer remains open; use SAVE ANATOMY when ready.');
            elseif isLowResAnatomy
                localGuiLog(cfg,'Low-res anatomy not auto-saved. Use SAVE LOW-RES in the Trigger Controller when wanted.');
            end
        end

        fprintf('Elapsed time: %.1f seconds\n', toc(tTrial));

 doPauseNow = false;

if isSplitMotor
    % In split mode, do NOT pause between slice files.
    % Only pause after the full split trial is finished.
    doPauseNow = (iMotor == nMotorLoopThisRun) && (iTrial < cfg.n_trials);
else
    doPauseNow = acqCounter < totalAcqCount;
end

if doPauseNow
    localGuiStatus(cfg, 'Waiting before next trial...', 'notready');
    localSafePause(cfg.time_pause);
end
    end
end

        % After split motor acquisition is completely finished,
        % write ONE summary TXT and ONE journal entry.
        if isSplitMotor && ~isempty(splitLastNameFile)
            try
                localWriteSplitSessionSummaryText( ...
                    cfg, splitSessionRows, splitLastNameFile, splitLastTrial, splitLastMd);
            catch MEsum
                localGuiLog(cfg, sprintf('Split summary TXT warning: %s', MEsum.message));
            end

            try
                FS.writeJournal(sprintf( ...
                    '* Split motor session finished | Folder=%s | Files=%d | Frames/trial=%d | Frames/slice=%d', ...
                    fileparts(splitLastNameFile), numel(splitSessionRows), ...
                    cfg.n_frames, round(cfg.motor.frames_per_position)));
            catch MEj
                localGuiLog(cfg, sprintf('Final split journal warning: %s', MEj.message));
            end
        end

        localGuiStatus(cfg, 'Experiment finished successfully.', 'ready');
        localGuiLog(cfg, 'Experiment finished successfully.');

    catch ME
        if strcmp(ME.identifier, 'vfUSI:UserStop')
            userStopped = true;
            localGuiStatus(cfg, 'Experiment stopped by user.', 'notready');
            localGuiLog(cfg, 'Experiment stopped by user.');
        else
            localGuiStatus(cfg, sprintf('Error: %s', ME.message), 'error');
            localGuiLog(cfg, sprintf('ERROR: %s', ME.message));
            fprintf(2, 'ERROR in vfUSI_StimBox_TTL_EACH_FRAME_OR_TRIGGER_ACCESSORIES_COMMAND:\n');
            fprintf(2, '  %s\n', ME.message);
            localCleanup();
            rethrow(ME);
        end
    end

    localCleanup();

    if userStopped
        return;
    end

    % =====================================================================
    % Cleanup
    % =====================================================================
     function localCleanup()
        if cfg.motor.enable
            try
                if ~isempty(motorAxis) && ~isnan(motorHomeMM) && cfg.motor.return_to_zero
                    localGuiStatus(cfg, 'Returning motor to home position...', 'notready');
                    motorAxis.moveAbsolute(motorHomeMM, zaber.motion.Units.LENGTH_MILLIMETRES);
                    localSafePause(0.10);
                end
            catch
            end

            try
                if ~isempty(motorConnection)
                    motorConnection.close();
                end
            catch
            end
        end

        try
            if ~isempty(port)
                if strcmpi(class(port), 'serial')
                    if strcmpi(port.Status, 'open')
                        fclose(port);
                    end
                    delete(port);

                    try
                        delete(instrfind('Port', cfg.stimbox.com));
                    catch
                    end

                elseif strcmpi(class(port), 'serialport')
                    delete(port);
                end
            end
        catch
        end

        if pulsePalConnected
            localClosePulsePalRobust();
        end
     end


% =========================================================================
% Safe processRF bridge
% =========================================================================
function rfOut = localProcessRFBridge(pp, rfIn)
    % Safe bridge for echoScan processRF.
    %
    % Some OpenfUS / echoScan versions expect the processRF callback to
    % return RF data, but the collaborator-style pp.newImage callback often
    % has NO output argument.
    %
    % Therefore:
    %   - call pp.newImage(rfIn) only for side effects:
    %       GUI frame update, StimBox, PulsePal, stop check
    %   - always return rfIn unchanged to echoScan
    %   - motor movement is NOT handled here

    rfOut = rfIn;

    try
        pp.newImage(rfIn);   % no output expected from object callback
    catch ME
        rethrow(ME);
    end
end

function [I, md, actualFrames, acqElapsedSec, requestedDtSec, actualMeanDtSec] = ...
    localRunSelectedAcquisition(SCAN, pp, cfg, nFramesThis)

    nFramesThis = max(1, round(nFramesThis));
    localSetObjPropIfExists(pp, 'total_frames', nFramesThis);

    imagingMode = localGetImagingMode(cfg);
    useProcessRF = localShouldUseProcessRF(cfg);
    processRFCallback = [];
    if useProcessRF
        processRFCallback = @pp.newImage;
    end

    fullTic = tic;

    try
        switch imagingMode
            case 'doppler'
                % V7 low-resolution anatomy uses the COMPANY'S OWN Doppler
                % callback/display path whenever the quick 5 x 16 anatomy
                % preset is selected with accessories off. This is the only
                % reliable way to get exactly the same filtering, scaling,
                % gamma, colormap and colorbar as the company GUI. We then
                % capture the already-rendered scalar CData for optional save.
                if localIsLowResAnatomyPreset(cfg) && ~useProcessRF && ...
                        ~(isfield(cfg,'motor') && isstruct(cfg.motor) && logical(cfg.motor.enable))
                    localGuiLog(cfg, 'Low-res anatomy V16: using native company Doppler callback/display path and mirroring the rendered native display into Trigger Controller.');
                    [I, md] = vfUSI_OpenfUS_UIBridge('doppler', SCAN, cfg, nFramesThis);
                    acqElapsedSec = toc(fullTic);
                    actualFrames = nFramesThis;
                elseif useProcessRF
                    localGuiLog(cfg, 'Doppler: using processRF callback.');
                    [I, md] = SCAN.doppler(cfg.nblocksImage, nFramesThis, ...
                        'processRF', processRFCallback);
                    acqElapsedSec = toc(fullTic);
                    actualFrames = localGetAcquiredFrameCount(I, nFramesThis);
                else
                    localGuiLog(cfg, 'Doppler: using plain SCAN.doppler.');
                    [I, md] = SCAN.doppler(cfg.nblocksImage, nFramesThis);
                    acqElapsedSec = toc(fullTic);
                    actualFrames = localGetAcquiredFrameCount(I, nFramesThis);
                end


            case 'functional'
                % Explicit long functional fUSI time series. This is the
                % original normal Doppler movie path: no company single-image
                % anatomy callback and no static reduction. The full I array
                % is returned and therefore auto-saved by the normal pipeline.
                if useProcessRF
                    localGuiLog(cfg, sprintf( ...
                        'Functional fUSI: acquiring %d frames x %d blocks/image with live progress/TR callback.', ...
                        nFramesThis, cfg.nblocksImage));
                    [I, md] = SCAN.doppler(cfg.nblocksImage, nFramesThis, ...
                        'processRF', processRFCallback);
                else
                    localGuiLog(cfg, sprintf( ...
                        'Functional fUSI: acquiring %d frames x %d blocks/image using plain SCAN.doppler.', ...
                        nFramesThis, cfg.nblocksImage));
                    [I, md] = SCAN.doppler(cfg.nblocksImage, nFramesThis);
                end
                acqElapsedSec = toc(fullTic);
                actualFrames = localGetAcquiredFrameCount(I, nFramesThis);

            case 'highres2d'
                if exist('highResAcq2D', 'file') ~= 2
                    error(['highResAcq2D.m was not found on the MATLAB path. ' ...
                           'Place the updated helper in the acquisition folder.']);
                end

                localGuiLog(cfg, sprintf( ...
                    'High-Res 2D: %d source frames, fixed nblocksImage=10.', nFramesThis));
                if nFramesThis < 50
                    localGuiLog(cfg, sprintf('HR2D WARNING: only %d source frames requested; company demo recommends 100.',nFramesThis));
                end
                % V13 returns the high-resolution path to the vendor architecture: the
                % supplied company HR helpers create a fresh echoScan object. Reusing the
                % normal Doppler SCAN can leave HR beamforming state partially inherited
                % and was a plausible cause of the all-black reconstruction.
                [I, ~, md] = highResAcq2D(nFramesThis, [], processRFCallback);

                fullElapsed = toc(fullTic);
                acqElapsedSec = localGetHighResDopplerElapsed(md, fullElapsed);
                actualFrames = localGetHighResFrameCount(md, nFramesThis);
                try
                    md.highres_total_elapsed_s = fullElapsed;
                catch
                end
                localLogHighResMetadataMode(cfg, md);

            case 'highres3d'
                if exist('highResAcq3D', 'file') ~= 2
                    error(['highResAcq3D.m was not found on the MATLAB path. ' ...
                           'Place the updated helper in the acquisition folder.']);
                end

                localGuiLog(cfg, sprintf( ...
                    'High-Res 3D: %d source volumes, fixed nblocksImage=17.', nFramesThis));
                if nFramesThis < 50
                    localGuiLog(cfg, sprintf('HR3D WARNING: only %d source volumes requested; company demo recommends 100.',nFramesThis));
                end
                % Vendor-faithful V13 path: highResAcq3D creates its own echoScan object,
                % matching the supplied company helper before switching to paramMatrixHR.
                % The normal Doppler/B-mode SCAN remains untouched.
                [I, md] = highResAcq3D(nFramesThis, [], processRFCallback);

                fullElapsed = toc(fullTic);
                acqElapsedSec = localGetHighResDopplerElapsed(md, fullElapsed);
                actualFrames = localGetHighResFrameCount(md, nFramesThis);
                try
                    md.highres_total_elapsed_s = fullElapsed;
                catch
                end
                localLogHighResMetadataMode(cfg, md);

            otherwise
                error('Unsupported imaging mode: %s', imagingMode);
        end

    catch ME
        localGuiLog(cfg, sprintf('%s acquisition failed: %s', imagingMode, ME.message));
        rethrow(ME);
    end

    requestedDtSec = localCalcTRSec(cfg.nblocksImage, localGetTRUnit(cfg));
    isVendorNativeDisplay = isstruct(md) && isfield(md,'vendor_native_display') && ...
        logical(md.vendor_native_display);
    if isVendorNativeDisplay
        actualMeanDtSec = NaN;
    else
        actualMeanDtSec = acqElapsedSec / max(1, actualFrames);
    end

    try
        md.requested_dt_s = requestedDtSec;
        md.actual_acq_elapsed_s = acqElapsedSec;
        md.actual_frames_saved = actualFrames;
        md.actual_mean_dt_s = actualMeanDtSec;
        md.actual_dt_deviation_s = actualMeanDtSec - requestedDtSec;
        md.actual_dt_deviation_percent = 100 * ...
            (actualMeanDtSec - requestedDtSec) / requestedDtSec;
    catch
    end

    if requestedDtSec > 0 && ~isVendorNativeDisplay && isfinite(actualMeanDtSec)
        devPct = 100 * (actualMeanDtSec - requestedDtSec) / requestedDtSec;
        localGuiTiming(cfg, requestedDtSec, actualMeanDtSec, ...
            devPct, acqElapsedSec, actualFrames);

        if abs(devPct) > 15 || abs(actualMeanDtSec - requestedDtSec) > 0.050
            localGuiLog(cfg, sprintf( ...
                'TR WARNING after acquisition: requested %.3f s, actual mean %.3f s (%+.1f%%).', ...
                requestedDtSec, actualMeanDtSec, devPct));
        else
            localGuiLog(cfg, sprintf( ...
                'Timing QC: requested %.3f s, actual mean %.3f s (%+.1f%%).', ...
                requestedDtSec, actualMeanDtSec, devPct));
        end
    end
end

function n = localGetHighResFrameCount(md, fallbackN)
    n = fallbackN;
    try
        if isstruct(md) && isfield(md, 'time') && isnumeric(md.time) && ~isempty(md.time)
            n = numel(md.time);
        elseif isstruct(md) && isfield(md, 'highres_nframes_used') && ...
                isnumeric(md.highres_nframes_used) && isscalar(md.highres_nframes_used)
            n = md.highres_nframes_used;
        end
    catch
        n = fallbackN;
    end
    if isempty(n) || ~isfinite(n) || n < 1
        n = fallbackN;
    end
    n = max(1, round(n));
end

function t = localGetHighResDopplerElapsed(md, fallbackT)
    t = fallbackT;
    try
        if isstruct(md) && isfield(md, 'highres_doppler_elapsed_s') && ...
                isnumeric(md.highres_doppler_elapsed_s) && ...
                isscalar(md.highres_doppler_elapsed_s) && ...
                isfinite(md.highres_doppler_elapsed_s) && md.highres_doppler_elapsed_s > 0
            t = md.highres_doppler_elapsed_s;
        end
    catch
        t = fallbackT;
    end
end

function [I, md] = localRunVendorDopplerAnatomy(SCAN, cfg, nFramesThis)
    % V7 NATIVE COMPANY DOPPLER ANATOMY
    % -------------------------------------------------------------
    % Do not redraw SCAN.doppler output ourselves. The company GUI applies
    % additional display/processing steps that are not exposed in the supplied
    % scripts/P-code. For the quick 5 x 16 anatomy preset we therefore invoke
    % the company's own Doppler control and capture the scalar CData AFTER the
    % company has displayed it. This guarantees that the user sees the exact
    % company image, colormap, CLim, gamma and colorbar.

    [hDoppler, hVendorFig, whyFound] = localFindVendorGraphicsControl('doppler', false, []);
    if isempty(hDoppler) || ~ishandle(hDoppler)
        localLogVendorGraphicsCandidates(cfg, 'doppler');
        error(['Could not identify the native company Doppler control. ' ...
               'V7 will not substitute a differently processed low-res image.']);
    end

    [axBefore, ~] = localFindVendorDisplayAxes();
    sigBefore = localVendorAxesSignature(axBefore);

    localGuiLog(cfg, sprintf('Native company Doppler control found (%s | type=%s | figure="%s").', ...
        whyFound, localAnyToText(localSafeGet(hDoppler,'Type')), localGetFigureName(hVendorFig)));
    localGuiLog(cfg, 'Starting native company Doppler acquisition. Display settings are not modified.');

    localInvokeVendorGraphicsControl(hDoppler, true);
    drawnow;

    % Some company callbacks return only after acquisition; others schedule
    % their final display update asynchronously. Poll briefly for a changed
    % image without touching the display itself.
    tWait = tic;
    axNow = [];
    while toc(tWait) < 12
        [axNow, ~] = localFindVendorDisplayAxes();
        sigNow = localVendorAxesSignature(axNow);
        if localVendorSignatureChanged(sigBefore, sigNow)
            if ~isempty(axNow) && ishandle(axNow)
                break;
            end
        elseif ~sigBefore.valid && sigNow.valid && toc(tWait) > 0.25
            break;
        end
        drawnow;
        pause(0.05);
    end

    if isempty(axNow) || ~ishandle(axNow)
        [axNow, ~] = localFindVendorDisplayAxes();
    end
    [I, cap] = localCaptureVendorDisplayedImage(axNow);
    if isempty(I)
        error('Company Doppler callback completed, but no displayed image CData could be captured.');
    end

    md = localBuildVendorCaptureMetadata(SCAN, I, nFramesThis);
    md.vendor_native_display = true;
    md.vendor_native_control_reason = whyFound;
    md.vendor_capture_source = cap.source;
    md.vendor_capture_original_class = cap.original_class;
    md.vendor_capture_original_size = cap.original_size;
    md.vendor_capture_was_rgb = cap.was_rgb;
    md.vendor_capture_axes_clim = cap.clim;
    md.vendor_capture_colormap = cap.colormap;
    md.vendor_capture_note = [ ...
        'I is the scalar image captured from the native company Doppler display after acquisition. ' ...
        'The company GUI itself remains the authoritative visual display.'];

    localGuiLog(cfg, sprintf('Native company Doppler displayed and captured for optional save: size=%s class=%s.', ...
        mat2str(size(I)), class(I)));
end

function md = localBuildVendorCaptureMetadata(SCAN, I, nFramesThis)
    md = struct();
    md.imageDim = ndims(I);
    if ismatrix(I), md.imageDim = 2; end
    md.imageSize = size(I);
    md.imageType = 'doppler';
    md.time = 1:max(1,round(nFramesThis));
    md.t0 = clock;
    md.tag = struct();
    md.voxelSize = NaN(1,md.imageDim);
    md.origen = zeros(1,md.imageDim);
    try
        P = SCAN.parameters;
        if isfield(P,'bf') && isstruct(P.bf)
            rawVS = [localStructNumeric(P.bf,'dz') localStructNumeric(P.bf,'dx') localStructNumeric(P.bf,'dy')];
            rawOrg = [localStructNumeric(P.bf,'z0') localStructNumeric(P.bf,'x0') localStructNumeric(P.bf,'y0')];
            n = min(md.imageDim,numel(rawVS));
            md.voxelSize(1:n) = rawVS(1:n);
            md.origen(1:n) = rawOrg(1:n);
        end
    catch
    end
end

function v = localStructNumeric(s, name)
    v = NaN;
    try
        if isfield(s,name)
            x = s.(name);
            if isnumeric(x) && isscalar(x) && isfinite(x), v = double(x); end
        end
    catch
    end
end

function sig = localVendorAxesSignature(ax)
    sig = struct('valid',false,'sz',[],'a',NaN,'b',NaN,'c',NaN);
    try
        if isempty(ax) || ~ishandle(ax), return; end
        imgs = findall(ax,'Type','image');
        if isempty(imgs), return; end
        best = []; bestN = -1;
        for k=1:numel(imgs)
            cd = get(imgs(k),'CData');
            if isnumeric(cd) && numel(cd)>bestN
                best=cd; bestN=numel(cd);
            end
        end
        if isempty(best), return; end
        x=double(best(:)); x=x(isfinite(x));
        if isempty(x), return; end
        sig.valid=true; sig.sz=size(best);
        sig.a=x(1); sig.b=x(max(1,round(numel(x)/2))); sig.c=x(end);
    catch
    end
end

function tf = localVendorSignatureChanged(a,b)
    tf = false;
    try
        if ~a.valid && b.valid, tf=true; return; end
        if ~(a.valid && b.valid), return; end
        if ~isequal(a.sz,b.sz), tf=true; return; end
        tf = ~(isequaln(a.a,b.a) && isequaln(a.b,b.b) && isequaln(a.c,b.c));
    catch
    end
end

function [I, cap] = localCaptureVendorDisplayedImage(ax)
    I = [];
    cap = struct('source','','original_class','','original_size',[], ...
        'was_rgb',false,'clim',[],'colormap',[]);
    if isempty(ax) || ~ishandle(ax), return; end
    try
        imgs = findall(ax,'Type','image');
        if isempty(imgs), return; end
        hBest=[]; bestN=-1;
        for k=1:numel(imgs)
            cd=get(imgs(k),'CData');
            if isnumeric(cd) && numel(cd)>bestN
                hBest=imgs(k); bestN=numel(cd);
            end
        end
        if isempty(hBest), return; end
        cd=get(hBest,'CData');
        cap.source='company_axes_CData';
        cap.original_class=class(cd);
        cap.original_size=size(cd);
        cap.clim=get(ax,'CLim');
        try
            hf=ancestor(ax,'figure'); cap.colormap=colormap(hf);
        catch
        end
        if ndims(cd)==3 && size(cd,3)==3
            cap.was_rgb=true;
            d=double(cd);
            I=0.2989360213*d(:,:,1)+0.5870430745*d(:,:,2)+0.1140209043*d(:,:,3);
        else
            I=cd;
        end
    catch
        I=[];
    end
end

function localRunBModeLive(SCAN, cfg) %#ok<INUSD>
    % V7 native B-mode discovery includes classic uicontrols, hidden toolbar
    % tools, toggle tools and menus. V6 looked only at uicontrols and therefore
    % could miss the actual LIVE/FREEZE tool used by protected OpenfUS builds.
    % No color/gamma/CLim property is changed here.

    localGuiStatus(cfg, 'B-Mode LIVE - press STOP to end', 'notready');
    localGuiLog(cfg, 'B-Mode Live V7: locating native B-mode + LIVE/FREEZE graphics controls (including toolbar/menu tools).');

    [hBMode,hVendorFig,whyB] = localFindVendorGraphicsControl('bmode', false, []);
    [hLive,hLiveFig,whyLive] = localFindVendorGraphicsControl('bmode', true, []);

    if isempty(hLive) || ~ishandle(hLive)
        % If there is no combined B-mode+live control, search for a generic
        % Live/Run/Continuous toggle in the same company figure.
        if ~isempty(hBMode) && ishandle(hBMode)
            [hLive,hLiveFig,whyLive] = localFindVendorGraphicsControl('live', false, hVendorFig);
        end
    end

    % A B-mode toggle tool itself can be the live/freeze state even if its
    % label contains only "B-MODE". Accept it only for stateful controls;
    % never treat a plain pushbutton snapshot as continuous live.
    if (isempty(hLive) || ~ishandle(hLive)) && ~isempty(hBMode) && ishandle(hBMode)
        typ=lower(localAnyToText(localSafeGet(hBMode,'Type')));
        sty=lower(localAnyToText(localSafeGet(hBMode,'Style')));
        if strcmp(typ,'uitoggletool') || strcmp(sty,'togglebutton') || strcmp(sty,'radiobutton')
            hLive=hBMode; hLiveFig=hVendorFig; whyLive=['stateful B-mode control: ' whyB];
        end
    end

    if isempty(hLive) || ~ishandle(hLive)
        localLogVendorGraphicsCandidates(cfg, 'bmode');
        error([ ...
            'Could not identify a stateful native B-Mode LIVE/FREEZE control. ' ...
            'The protected company GUI does not expose a callable continuous control under the properties V7 can inspect. ' ...
            'No snapshot loop was started and no display setting was changed.']);
    end

    % If a separate B-mode selector exists, select/initialize it once first.
    if ~isempty(hBMode) && ishandle(hBMode) && hBMode~=hLive
        localGuiLog(cfg,sprintf('Selecting native B-mode once (%s).',whyB));
        localInvokeVendorGraphicsControl(hBMode,true);
        drawnow;
    end

    localGuiLog(cfg,sprintf('Starting native LIVE once (%s | type=%s | figure="%s").', ...
        whyLive,localAnyToText(localSafeGet(hLive,'Type')),localGetFigureName(hLiveFig)));

    % A native live callback may block until FREEZE/STOP. Start a small MATLAB
    % timer BEFORE invoking it so the Trigger Controller STOP button can still
    % call the company STOP/FREEZE control while the native callback is active.
    stopTimer=[];
    try
        stopTimer=timer('ExecutionMode','fixedSpacing','Period',0.10, ...
            'BusyMode','drop','UserData',struct('fired',false), ...
            'TimerFcn',@(tm,evt)localBModeStopTimer(tm,cfg,hLive,hLiveFig));
        start(stopTimer);
    catch MEtimer
        localGuiLog(cfg,['B-Mode stop-timer warning: ' MEtimer.message]);
    end
    timerCleanup=onCleanup(@()localDeleteTimerSafe(stopTimer)); %#ok<NASGU>

    localInvokeVendorGraphicsControl(hLive,true);
    drawnow;

    while ~localStopRequested(cfg)
        if ~ishandle(hLive), break; end
        drawnow;
        pause(0.03);
    end

    % If the timer already fired the company STOP control, do NOT invoke the
    % toggle again here (that could accidentally restart live mode).
    alreadyStopped=localTimerAlreadyFired(stopTimer);
    if ~alreadyStopped
        [hStop,~,whyStop] = localFindVendorGraphicsControl('stop',false,hLiveFig);
        try
            if ~isempty(hStop) && ishandle(hStop) && hStop~=hLive
                localGuiLog(cfg,['Stopping native B-mode using ' whyStop '.']);
                localInvokeVendorGraphicsControl(hStop,true);
            else
                localGuiLog(cfg,'Stopping native B-mode by switching the LIVE toggle OFF once.');
                localInvokeVendorGraphicsControl(hLive,false);
            end
        catch MEoff
            localGuiLog(cfg,['B-Mode stop warning: ' MEoff.message]);
        end
    end

    localGuiStatus(cfg,'B-Mode Live stopped.','ready');
    localGuiLog(cfg,'B-Mode Live stopped. Company display settings were never modified.');
end

function localBModeStopTimer(tm,cfg,hLive,hLiveFig)
    try
        ud=get(tm,'UserData');
        if isstruct(ud) && isfield(ud,'fired') && ud.fired, return; end
        if ~localStopRequested(cfg), return; end
        if ~isstruct(ud), ud=struct(); end
        ud.fired=true; set(tm,'UserData',ud);
        [hStop,~,~]=localFindVendorGraphicsControl('stop',false,hLiveFig);
        if ~isempty(hStop) && ishandle(hStop) && hStop~=hLive
            localInvokeVendorGraphicsControl(hStop,true);
        elseif ~isempty(hLive) && ishandle(hLive)
            localInvokeVendorGraphicsControl(hLive,false);
        end
        try, stop(tm); catch, end
    catch
    end
end

function tf=localTimerAlreadyFired(tm)
    tf=false;
    try
        if isempty(tm) || ~isvalid(tm), return; end
        ud=get(tm,'UserData');
        tf=isstruct(ud) && isfield(ud,'fired') && logical(ud.fired);
    catch
        tf=false;
    end
end

function localDeleteTimerSafe(tm)
    try
        if isempty(tm), return; end
        try, stop(tm); catch, end
        try, delete(tm); catch, end
    catch
    end
end

function [hBest,hBestFig,why] = localFindVendorGraphicsControl(mode, requireCombinedLive, restrictFig)
    hBest=[]; hBestFig=[]; why=''; bestScore=-Inf;
    oldHidden='off';
    try, oldHidden=get(0,'ShowHiddenHandles'); set(0,'ShowHiddenHandles','on'); catch, end
    cleanupHidden=onCleanup(@()localRestoreHiddenHandles(oldHidden)); %#ok<NASGU>
    if nargin<2, requireCombinedLive=false; end
    if nargin<3, restrictFig=[]; end
    if ~isempty(restrictFig) && ishandle(restrictFig)
        figs=restrictFig;
    else
        try, figs=findall(0,'Type','figure'); catch, figs=[]; end
    end
    for iFig=1:numel(figs)
        hf=figs(iFig);
        if localIsOurControllerFigure(hf), continue; end
        fName=lower(localGetFigureName(hf));
        figBonus=0; if ~isempty(strfind(fName,'openfus')), figBonus=40; end
        try, objs=findall(hf); catch, objs=[]; end
        for k=1:numel(objs)
            h=objs(k);
            typ=lower(localAnyToText(localSafeGet(h,'Type')));
            if ~any(strcmp(typ,{'uicontrol','uipushtool','uitoggletool','uimenu'})), continue; end
            [key,cbtxt]=localGraphicsControlText(h);
            compact=regexprep(lower(key),'[^a-z0-9]','');
            score=-Inf; desc='';
            switch lower(mode)
                case 'doppler'
                    if isempty(strfind(compact,'doppler')), continue; end
                    if ~isempty(strfind(compact,'save')) || ~isempty(strfind(compact,'color')) || ...
                            ~isempty(strfind(compact,'gamma')) || ~isempty(strfind(compact,'gain'))
                        continue;
                    end
                    score=220+figBonus; desc='native company Doppler control';
                case 'bmode'
                    hasB=~isempty(strfind(compact,'bmode')) || ...
                        (~isempty(strfind(compact,'b')) && ~isempty(strfind(compact,'mode')));
                    if ~hasB, continue; end
                    hasLive=~isempty(strfind(compact,'live')) || ~isempty(strfind(compact,'continuous')) || ...
                        ~isempty(strfind(compact,'freeze')) || ~isempty(strfind(compact,'run'));
                    if requireCombinedLive && ~hasLive, continue; end
                    score=220+figBonus+80*hasLive; desc='native company B-mode control';
                case 'live'
                    hasLive=~isempty(strfind(compact,'live')) || ~isempty(strfind(compact,'continuous')) || ...
                        ~isempty(strfind(compact,'freeze')) || ~isempty(strfind(compact,'run')) || ...
                        ~isempty(strfind(compact,'start'));
                    if ~hasLive, continue; end
                    bad=~isempty(strfind(compact,'doppler')) || ~isempty(strfind(compact,'motor')) || ...
                        ~isempty(strfind(compact,'save')) || ~isempty(strfind(compact,'record'));
                    if bad, continue; end
                    score=160+figBonus; desc='generic native LIVE/CONTINUOUS/FREEZE control';
                case 'stop'
                    hasStop=~isempty(strfind(compact,'stop')) || ~isempty(strfind(compact,'freeze')) || ...
                        ~isempty(strfind(compact,'off'));
                    if ~hasStop, continue; end
                    bad=~isempty(strfind(compact,'motor')) || ~isempty(strfind(compact,'pulsepal')) || ...
                        ~isempty(strfind(compact,'stimbox'));
                    if bad, continue; end
                    score=150+figBonus; desc='native STOP/FREEZE control';
                otherwise
                    continue;
            end
            if strcmp(typ,'uitoggletool'), score=score+55; end
            sty=lower(localAnyToText(localSafeGet(h,'Style')));
            if strcmp(sty,'togglebutton') || strcmp(sty,'radiobutton'), score=score+45; end
            if ~isempty(cbtxt), score=score+20; end
            if score>bestScore
                bestScore=score; hBest=h; hBestFig=hf;
                why=sprintf('%s; key="%s"',desc,strtrim(key));
            end
        end
    end
end

function [key,cbtxt] = localGraphicsControlText(h)
    vals={};
    props={'String','Label','Tag','TooltipString','Tooltip'};
    for i=1:numel(props)
        try, vals{end+1}=localAnyToText(get(h,props{i})); catch, end %#ok<AGROW>
    end
    cbtxt='';
    cbprops={'Callback','ClickedCallback','OnCallback','OffCallback','MenuSelectedFcn','ButtonDownFcn'};
    for i=1:numel(cbprops)
        try
            c=get(h,cbprops{i}); t=localCallbackToText(c);
            if ~isempty(t), vals{end+1}=t; cbtxt=[cbtxt ' ' t]; end %#ok<AGROW>
        catch
        end
    end
    key=strjoin(vals,' ');
end

function localInvokeVendorGraphicsControl(h, turnOn)
    if isempty(h) || ~ishandle(h), error('Invalid native graphics control handle.'); end
    typ=lower(localAnyToText(localSafeGet(h,'Type')));
    sty=lower(localAnyToText(localSafeGet(h,'Style')));
    cb=[];
    if strcmp(typ,'uitoggletool')
        if turnOn
            try, set(h,'State','on'); catch, end
            try, cb=get(h,'OnCallback'); catch, end
        else
            try, set(h,'State','off'); catch, end
            try, cb=get(h,'OffCallback'); catch, end
        end
        if isempty(cb), try, cb=get(h,'ClickedCallback'); catch, end, end
    elseif strcmp(typ,'uipushtool')
        try, cb=get(h,'ClickedCallback'); catch, end
    elseif strcmp(typ,'uimenu')
        try, cb=get(h,'MenuSelectedFcn'); catch, end
        if isempty(cb), try, cb=get(h,'Callback'); catch, end, end
    elseif strcmp(typ,'uicontrol')
        if strcmp(sty,'togglebutton') || strcmp(sty,'radiobutton') || strcmp(sty,'checkbox')
            try, set(h,'Value',double(logical(turnOn))); catch, end
        end
        try, cb=get(h,'Callback'); catch, end
    end
    if isempty(cb), try, cb=get(h,'ButtonDownFcn'); catch, end, end
    if isempty(cb), error('Detected native control has no callable callback.'); end
    localExecuteGraphicsCallback(cb,h);
end

function localExecuteGraphicsCallback(cb,h)
    if isa(cb,'function_handle')
        feval(cb,h,[]); return;
    end
    if iscell(cb) && ~isempty(cb)
        f=cb{1}; extra=cb(2:end);
        if isa(f,'function_handle'), feval(f,h,[],extra{:}); return; end
        if ischar(f), feval(f,h,[],extra{:}); return; end
    end
    if ischar(cb) && ~isempty(strtrim(cb))
        eval(cb); return;
    end
    error('Unsupported native callback type: %s',class(cb));
end

function localLogVendorGraphicsCandidates(cfg, focus)
    try
        oldHidden=get(0,'ShowHiddenHandles'); set(0,'ShowHiddenHandles','on');
        c=onCleanup(@()localRestoreHiddenHandles(oldHidden)); %#ok<NASGU>
        figs=findall(0,'Type','figure');
        n=0;
        for i=1:numel(figs)
            hf=figs(i); if localIsOurControllerFigure(hf), continue; end
            objs=findall(hf);
            for k=1:numel(objs)
                h=objs(k); typ=lower(localAnyToText(localSafeGet(h,'Type')));
                if ~any(strcmp(typ,{'uicontrol','uipushtool','uitoggletool','uimenu'})), continue; end
                [key,~]=localGraphicsControlText(h);
                lk=lower(key);
                if isempty(strfind(lk,lower(focus))) && ...
                        isempty(strfind(lk,'live')) && isempty(strfind(lk,'freeze')) && ...
                        isempty(strfind(lk,'continuous')) && isempty(strfind(lk,'doppler')) && ...
                        isempty(strfind(lk,'bmode'))
                    continue;
                end
                n=n+1;
                localGuiLog(cfg,sprintf('OpenfUS control candidate %d: type=%s | figure="%s" | %s', ...
                    n,typ,localGetFigureName(hf),strtrim(key)));
                if n>=30, return; end
            end
        end
        if n==0, localGuiLog(cfg,'No matching native OpenfUS control candidates were exposed as MATLAB graphics handles.'); end
    catch ME
        localGuiLog(cfg,['Native control diagnostic warning: ' ME.message]);
    end
end

function localRestoreHiddenHandles(v)
    try, set(0,'ShowHiddenHandles',v); catch, end
end

function [hBest, hBestFig, why] = localFindVendorBModeLiveControl()
    hBest = []; hBestFig = []; why = ''; bestScore = -Inf;
    try, figs = findall(0,'Type','figure'); catch, figs = []; end
    for iFig = 1:numel(figs)
        hFig = figs(iFig);
        if localIsOurControllerFigure(hFig), continue; end
        fName = lower(localGetFigureName(hFig));
        figBonus = 0; if ~isempty(strfind(fName,'openfus')), figBonus = 40; end
        try, ctrls = findall(hFig,'Type','uicontrol'); catch, ctrls = []; end
        for k = 1:numel(ctrls)
            h = ctrls(k);
            style = lower(localAnyToText(localSafeGet(h,'Style')));
            if isempty(strfind(style,'button')) && ~strcmp(style,'popupmenu'), continue; end
            s = localAnyToText(localSafeGet(h,'String'));
            t = localAnyToText(localSafeGet(h,'Tag'));
            tip = localAnyToText(localSafeGet(h,'TooltipString'));
            cb = localCallbackToText(localSafeGet(h,'Callback'));
            key = lower([s ' ' t ' ' tip ' ' cb]);
            compact = regexprep(key,'[^a-z0-9]','');
            hasB = ~isempty(strfind(compact,'bmode'));
            hasLive = ~isempty(strfind(compact,'live')) || ~isempty(strfind(compact,'continuous'));
            if ~(hasB && hasLive), continue; end
            score = figBonus + 200;
            if strcmp(style,'togglebutton') || strcmp(style,'radiobutton'), score = score + 35; end
            if ~isempty(strfind(lower(cb),'live')), score = score + 40; end
            if score > bestScore
                bestScore = score; hBest = h; hBestFig = hFig;
                why = 'control contains both B-mode and Live/Continuous';
            end
        end
    end
end

function [hBest, why] = localFindVendorGenericLiveControl(hFig, hExclude)
    hBest = []; why = ''; bestScore = -Inf;
    if isempty(hFig) || ~ishandle(hFig), return; end
    try, ctrls = findall(hFig,'Type','uicontrol'); catch, ctrls = []; end
    for k = 1:numel(ctrls)
        h = ctrls(k);
        if ~isempty(hExclude) && ishandle(hExclude) && h == hExclude, continue; end
        style = lower(localAnyToText(localSafeGet(h,'Style')));
        if isempty(strfind(style,'button')), continue; end
        s = localAnyToText(localSafeGet(h,'String'));
        t = localAnyToText(localSafeGet(h,'Tag'));
        tip = localAnyToText(localSafeGet(h,'TooltipString'));
        cb = localCallbackToText(localSafeGet(h,'Callback'));
        key = lower([s ' ' t ' ' tip ' ' cb]);
        compact = regexprep(key,'[^a-z0-9]','');
        hasLive = ~isempty(strfind(compact,'live')) || ~isempty(strfind(compact,'continuous'));
        if ~hasLive, continue; end
        % Do not mistake other subsystems for B-mode live.
        bad = ~isempty(strfind(compact,'doppler')) || ~isempty(strfind(compact,'motor')) || ...
              ~isempty(strfind(compact,'pulsepal')) || ~isempty(strfind(compact,'stimbox')) || ...
              ~isempty(strfind(compact,'save')) || ~isempty(strfind(compact,'record'));
        if bad, continue; end
        score = 120;
        if strcmp(style,'togglebutton') || strcmp(style,'radiobutton'), score = score + 30; end
        if ~isempty(strfind(lower(cb),'live')), score = score + 30; end
        if score > bestScore
            bestScore = score; hBest = h; why = 'generic company Live/Continuous control in the B-mode figure';
        end
    end
end

function hStop = localFindVendorLiveStopControl(hFig, hLive)
    hStop = []; bestScore = -Inf;
    if isempty(hFig) || ~ishandle(hFig), return; end
    try, ctrls = findall(hFig,'Type','uicontrol'); catch, ctrls = []; end
    for k = 1:numel(ctrls)
        h = ctrls(k);
        if ~isempty(hLive) && ishandle(hLive) && h == hLive, continue; end
        style = lower(localAnyToText(localSafeGet(h,'Style')));
        if isempty(strfind(style,'button')), continue; end
        key = lower([localAnyToText(localSafeGet(h,'String')) ' ' ...
            localAnyToText(localSafeGet(h,'Tag')) ' ' ...
            localAnyToText(localSafeGet(h,'TooltipString')) ' ' ...
            localCallbackToText(localSafeGet(h,'Callback'))]);
        compact = regexprep(key,'[^a-z0-9]','');
        hasStop = ~isempty(strfind(compact,'stop')) || ~isempty(strfind(compact,'liveoff'));
        if ~hasStop, continue; end
        bad = ~isempty(strfind(compact,'motor')) || ~isempty(strfind(compact,'stim')) || ...
              ~isempty(strfind(compact,'pulsepal'));
        if bad, continue; end
        score = 100; if ~isempty(strfind(compact,'live')), score = score + 50; end
        if score > bestScore, bestScore = score; hStop = h; end
    end
end

function localLogVendorLiveCandidates(cfg)
    try, figs = findall(0,'Type','figure'); catch, figs = []; end
    for iFig = 1:numel(figs)
        hFig = figs(iFig);
        if localIsOurControllerFigure(hFig), continue; end
        nm = localGetFigureName(hFig);
        if isempty(strfind(lower(nm),'openfus')), continue; end
        try, ctrls = findall(hFig,'Type','uicontrol'); catch, ctrls = []; end
        for k = 1:numel(ctrls)
            style = lower(localAnyToText(localSafeGet(ctrls(k),'Style')));
            if isempty(strfind(style,'button')), continue; end
            s = localAnyToText(localSafeGet(ctrls(k),'String'));
            t = localAnyToText(localSafeGet(ctrls(k),'Tag'));
            cb = localCallbackToText(localSafeGet(ctrls(k),'Callback'));
            key = lower([s ' ' t ' ' cb]);
            if ~isempty(strfind(key,'live')) || ~isempty(strfind(key,'bmode')) || ~isempty(strfind(key,'stop'))
                localGuiLog(cfg, sprintf('OpenfUS control candidate: style=%s | String="%s" | Tag="%s" | Callback="%s"', ...
                    style, s, t, cb));
            end
        end
    end
end

function [hBest, hBestFig, why] = localFindVendorBModeControl()
    hBest = [];
    hBestFig = [];
    why = '';
    bestScore = -Inf;

    try
        figs = findall(0, 'Type', 'figure');
    catch
        figs = [];
    end

    for iFig = 1:numel(figs)
        hFig = figs(iFig);

        if localIsOurControllerFigure(hFig)
            continue;
        end

        figName = lower(localGetFigureName(hFig));
        figBonus = 0;
        if ~isempty(strfind(figName, 'openfus'))
            figBonus = 25;
        end

        try
            ctrls = findall(hFig, 'Type', 'uicontrol');
        catch
            ctrls = [];
        end

        for iCtrl = 1:numel(ctrls)
            h = ctrls(iCtrl);

            try
                style = lower(get(h, 'Style'));
            catch
                style = '';
            end

            if isempty(strfind(style, 'button'))
                continue;
            end

            s = localAnyToText(localSafeGet(h, 'String'));
            t = localAnyToText(localSafeGet(h, 'Tag'));
            tip = localAnyToText(localSafeGet(h, 'TooltipString'));
            cbTxt = localCallbackToText(localSafeGet(h, 'Callback'));

            key = lower([s ' ' t ' ' tip ' ' cbTxt]);
            compact = regexprep(key, '[^a-z0-9]', '');

            score = figBonus;
            reason = '';

            if ~isempty(strfind(lower(cbTxt), 'bmode'))
                score = score + 150;
                reason = 'callback contains bmode';
            end

            if ~isempty(strfind(compact, 'bmode'))
                score = score + 100;
                if isempty(reason)
                    reason = 'label/tag contains bmode';
                end
            end

            if ~isempty(strfind(compact, 'bmodebutton'))
                score = score + 100;
                reason = 'native bmodeButton callback';
            end

            if score > bestScore && score >= 100
                bestScore = score;
                hBest = h;
                hBestFig = hFig;
                why = reason;
            end
        end
    end
end

function localInvokeControlCallback(h)
    if isempty(h) || ~ishandle(h)
        error('Invalid native GUI control handle.');
    end

    try
        hFig = ancestor(h, 'figure');
        if ~isempty(hFig) && ishandle(hFig)
            figure(hFig);
        end
    catch
    end

    cb = get(h, 'Callback');

    if isa(cb, 'function_handle')
        feval(cb, h, []);
        return;
    end

    if iscell(cb) && ~isempty(cb)
        f = cb{1};
        extra = cb(2:end);
        if isa(f, 'function_handle')
            feval(f, h, [], extra{:});
        elseif ischar(f)
            feval(f, h, [], extra{:});
        else
            error('Unsupported cell callback type: %s', class(f));
        end
        return;
    end

    if ischar(cb) && ~isempty(strtrim(cb))
        % Old GUIDE-style string callback.
        eval(cb);
        return;
    end

    error('The detected B-mode control has no callable Callback.');
end

function txt = localCallbackToText(cb)
    txt = '';
    try
        if isa(cb, 'function_handle')
            txt = func2str(cb);
        elseif ischar(cb)
            txt = cb;
        elseif iscell(cb) && ~isempty(cb)
            if isa(cb{1}, 'function_handle')
                txt = func2str(cb{1});
            elseif ischar(cb{1})
                txt = cb{1};
            end
        end
    catch
        txt = '';
    end
end

function v = localSafeGet(h, prop)
    v = '';
    try
        v = get(h, prop);
    catch
    end
end

function txt = localAnyToText(v)
    txt = '';
    try
        if ischar(v)
            txt = v;
        elseif iscell(v)
            parts = cell(size(v));
            for k = 1:numel(v)
                if ischar(v{k})
                    parts{k} = v{k};
                elseif isnumeric(v{k}) && isscalar(v{k})
                    parts{k} = num2str(v{k});
                else
                    parts{k} = '';
                end
            end
            txt = strjoin(parts, ' ');
        elseif isnumeric(v) && isscalar(v)
            txt = num2str(v);
        end
    catch
        txt = '';
    end
end

function tf = localIsOurControllerFigure(hFig)
    tf = false;
    try
        nm = lower(localGetFigureName(hFig));
        tg = lower(localAnyToText(get(hFig, 'Tag')));
        tf = ~isempty(strfind(nm, 'trigger controller')) || ...
             ~isempty(strfind(tg, 'vfusi_')) || ...
             ~isempty(strfind(nm, 'high-res')) || ...
             ~isempty(strfind(nm, 'doppler single image'));
    catch
        tf = false;
    end
end

function nm = localGetFigureName(hFig)
    nm = '';
    try
        x = get(hFig, 'Name');
        if ischar(x)
            nm = x;
        end
    catch
    end
end

function tf = localIsInputCountError(ME)
    tf = false;
    try
        msg = lower(ME.message);
        id = lower(ME.identifier);
        tf = ~isempty(strfind(msg, 'not enough input')) || ...
             ~isempty(strfind(msg, 'too many input')) || ...
             ~isempty(strfind(msg, 'insufficient number of input')) || ...
             ~isempty(strfind(id, 'notenoughinputs')) || ...
             ~isempty(strfind(id, 'maxrhs')) || ...
             ~isempty(strfind(id, 'minrhs'));
    catch
        tf = false;
    end
end

function localShowDopplerSingleImagePreview(I, cfg, md) %#ok<INUSD>
    % V7 LOW-RES DOPPLER DISPLAY - COMPANY STYLE PRESERVATION
    % ------------------------------------------------------------------
    % The controller must NOT choose a colormap, gamma, CLim or colorbar.
    % Those belong to the already-open company GUI. V5 could saturate the
    % image (often appearing all yellow) because raw Doppler CData was placed
    % into axes whose manual company CLim expected a different display range.
    %
    % V7 therefore:
    %   - changes only the native image object's CData;
    %   - leaves company CLim/colormap/colorbar/YDir/aspect untouched;
    %   - maps the new raw image into the previous company CData domain when
    %     a native reference image exists (or into the existing CLim domain);
    %   - re-fires gamma/color/contrast callbacks at their CURRENT values,
    %     so the company's own display transfer is reapplied without changing
    %     any user setting.

    try
        if isempty(I) || ~isnumeric(I), return; end
        [img, ~] = localBuildDopplerPreviewImage(I, cfg);
        if isempty(img), return; end

        [ax, hVendorFig] = localFindVendorDisplayAxes();
        if isempty(ax) || ~ishandle(ax)
            localGuiLog(cfg, 'Doppler display ERROR: main company OpenfUS image axes not found.');
            return;
        end

        oldCData = []; hTarget = [];
        try
            hImgs = findall(ax,'Type','image');
            if ~isempty(hImgs)
                hTarget = hImgs(1);
                oldCData = get(hTarget,'CData');
            end
        catch
        end

        imgDisp = localMapDopplerToVendorDisplayDomain(img, oldCData, ax);

        if ~isempty(hTarget) && ishandle(hTarget)
            % CData only. Do not change CDataMapping, axes limits, CLim, map,
            % colorbar, title, aspect ratio or direction.
            set(hTarget,'CData',imgDisp,'Visible','on');
        else
            % Empty-but-valid company acquisition axes. Create only the CData
            % object and inherit the axes/figure display settings already set
            % by OpenfUS. Do NOT call imagesc/colormap/caxis/axis/colorbar.
            image('Parent',ax,'CData',imgDisp,'CDataMapping','scaled','Visible','on');
        end

        % Reapply the company's CURRENT gamma/color/contrast callbacks without
        % changing any values. This is what makes an inserted image obey the
        % same UI settings that a company-acquired image uses.
        nRefreshed = localRefreshVendorDisplayControls(hVendorFig);
        drawnow;
        try, figure(hVendorFig); catch, end

        localGuiLog(cfg, sprintf( ...
            'Doppler displayed in company GUI with native CLim/gamma/colormap/colorbar preserved (%d display callbacks refreshed).', ...
            nRefreshed));
    catch MEprev
        localGuiLog(cfg, ['Doppler display warning: ' MEprev.message]);
    end
end

function out = localMapDopplerToVendorDisplayDomain(img, oldCData, ax)
    x = double(img);
    if ~isreal(x), x = abs(x); end
    x(~isfinite(x)) = 0;
    out = x;

    [newLo,newHi] = localRobustRange(x);
    if ~(isfinite(newLo) && isfinite(newHi) && newHi > newLo), return; end

    targetLo = NaN; targetHi = NaN;
    try
        if isnumeric(oldCData) && ismatrix(oldCData) && ~isempty(oldCData)
            od = double(oldCData);
            if ~isreal(od), od = abs(od); end
            od = od(isfinite(od));
            if ~isempty(od)
                [a,b] = localRobustRange(od);
                if isfinite(a) && isfinite(b) && b > a
                    targetLo = a; targetHi = b;
                end
            end
        end
    catch
    end

    if ~(isfinite(targetLo) && isfinite(targetHi) && targetHi > targetLo)
        try
            cl = get(ax,'CLim');
            if numel(cl)==2 && all(isfinite(cl)) && cl(2)>cl(1)
                targetLo = cl(1); targetHi = cl(2);
            end
        catch
        end
    end

    if isfinite(targetLo) && isfinite(targetHi) && targetHi > targetLo
        out = (x-newLo) ./ (newHi-newLo);
        out(out<0)=0; out(out>1)=1;
        out = targetLo + out.*(targetHi-targetLo);
    end
end

function [lo,hi] = localRobustRange(x)
    x = double(x(:)); x = x(isfinite(x));
    if isempty(x), lo=NaN; hi=NaN; return; end
    if numel(x) > 150000
        idx = round(linspace(1,numel(x),150000)); x = x(idx);
    end
    x = sort(x); n = numel(x);
    iLo = max(1,min(n,round(0.005*(n-1)+1)));
    iHi = max(1,min(n,round(0.995*(n-1)+1)));
    lo = x(iLo); hi = x(iHi);
    if ~(isfinite(hi) && hi>lo), lo=x(1); hi=x(end); end
end

function n = localRefreshVendorDisplayControls(hFig)
    n = 0;
    if isempty(hFig) || ~ishandle(hFig), return; end
    try, ctrls = findall(hFig,'Type','uicontrol'); catch, ctrls = []; end
    % Apply transfer/range first and colormap last, always at CURRENT values.
    groups = {'gamma','contrast','clim','caxis','minimum','maximum','min','max','colormap','colourmap','color'};
    used = {};
    for g = 1:numel(groups)
        token = groups{g};
        for k = 1:numel(ctrls)
            h = ctrls(k);
            alreadyUsed = false;
            for iu = 1:numel(used)
                if isequal(used{iu}, h), alreadyUsed = true; break; end
            end
            if alreadyUsed, continue; end
            style = lower(localAnyToText(localSafeGet(h,'Style')));
            if ~(strcmp(style,'slider') || strcmp(style,'edit') || strcmp(style,'popupmenu')), continue; end
            cb = localSafeGet(h,'Callback');
            cbTxt = localCallbackToText(cb);
            if isempty(cbTxt), continue; end
            key = lower([localAnyToText(localSafeGet(h,'String')) ' ' ...
                localAnyToText(localSafeGet(h,'Tag')) ' ' ...
                localAnyToText(localSafeGet(h,'TooltipString')) ' ' cbTxt]);
            compact = regexprep(key,'[^a-z0-9]','');
            if isempty(strfind(compact,token)), continue; end
            % Avoid unrelated acquisition parameters that happen to contain min/max.
            if (~isempty(strfind(compact,'frame')) || ~isempty(strfind(compact,'motor')) || ...
                    ~isempty(strfind(compact,'pulse')) || ~isempty(strfind(compact,'stim')))
                continue;
            end
            try
                localInvokeControlCallback(h);
                used{end+1}=h; %#ok<AGROW>
                n=n+1;
            catch
            end
        end
    end
end

function [img, titleTxt] = localBuildDopplerPreviewImage(I, cfg)
    img = [];
    titleTxt = 'Doppler / Low-Res Anatomy';

    sz = size(I);
    nD = ndims(I);
    probe3D = localIs3DProbe(cfg);

    if probe3D && nD >= 4
        % If an unreduced stack reaches this helper, use the final volume.
        vol = squeeze(I(:,:,:,end));
        midSlice = max(1, round(size(vol,3)/2));
        img = squeeze(vol(:,:,midSlice));
        titleTxt = sprintf('Low-res anatomy - final Doppler volume, slice %d/%d', ...
            midSlice, size(vol,3));
    elseif probe3D && nD == 3 && size(I,3) > 1
        midSlice = max(1, round(size(I,3)/2));
        img = squeeze(I(:,:,midSlice));
        titleTxt = sprintf('Low-res anatomy - slice %d/%d', midSlice, size(I,3));
    elseif ~probe3D && nD >= 3 && size(I,3) > 1
        img = squeeze(I(:,:,end));
        titleTxt = sprintf('Low-res anatomy - final Doppler image (%d acquired)', sz(3));
    else
        img = squeeze(I);
        titleTxt = 'Low-res anatomy - Doppler';
    end
end

function tf = localIsLowResAnatomyPreset(cfg)
    % The automatic Doppler quick-anatomy preset is exactly the combination
    % requested in the GUI: 5 images and nblocksImage=16, with no accessory
    % stimulation or motor movement. The explicit 'functional' mode can use
    % the same 16 blocks but is NEVER treated as low-res anatomy.
    tf = false;
    try
        tf = strcmpi(localGetImagingMode(cfg), 'doppler') && ...
            isfield(cfg, 'n_frames') && round(cfg.n_frames) == 5 && ...
            isfield(cfg, 'nblocksImage') && round(cfg.nblocksImage) == 16 && ...
            ~(isfield(cfg,'stimbox') && isstruct(cfg.stimbox) && ...
              isfield(cfg.stimbox,'enable') && logical(cfg.stimbox.enable)) && ...
            ~(isfield(cfg,'pulsepal') && isstruct(cfg.pulsepal) && ...
              isfield(cfg.pulsepal,'enable') && logical(cfg.pulsepal.enable)) && ...
            ~(isfield(cfg,'motor') && isstruct(cfg.motor) && ...
              isfield(cfg.motor,'enable') && logical(cfg.motor.enable));
    catch
        tf = false;
    end
end

function Istatic = localReduceDopplerToStaticAnatomy(I, cfg)
    %#ok<INUSD>
    % Keep the last completed Doppler image/volume. This is closer to what
    % the native OpenfUS live/single-image window leaves on screen and avoids
    % motion blur introduced by averaging the five quick anatomy frames.
    Istatic = I;
    if isempty(I) || ~isnumeric(I)
        return;
    end

    nD = ndims(I);
    if localIs3DProbe(cfg) && nD >= 4 && size(I,4) > 1
        Istatic = squeeze(I(:,:,:,end));
    elseif ~localIs3DProbe(cfg) && nD >= 3 && size(I,3) > 1
        Istatic = squeeze(I(:,:,end));
    else
        Istatic = squeeze(I);
    end
end

function [axBest, figBest] = localFindVendorDisplayAxes()
    % V5: choose the large acquisition axes, NOT the OpenfUS logo/banner.
    axBest = [];
    figBest = [];
    bestScore = -Inf;

    try
        figs = findall(0, 'Type', 'figure');
    catch
        figs = [];
    end

    for iFig = 1:numel(figs)
        hFig = figs(iFig);
        if localIsOurControllerFigure(hFig)
            continue;
        end

        figName = lower(localGetFigureName(hFig));
        figScore = 0;
        if ~isempty(strfind(figName, 'openfus'))
            figScore = figScore + 120;
        end

        % Vendor controls are better evidence than a pre-existing image.
        try
            ctrls = findall(hFig, 'Type', 'uicontrol');
            if numel(ctrls) >= 5
                figScore = figScore + 25;
            end
            for k = 1:numel(ctrls)
                cbTxt = lower(localCallbackToText(localSafeGet(ctrls(k), 'Callback')));
                key = lower([localAnyToText(localSafeGet(ctrls(k), 'String')) ' ' ...
                    localAnyToText(localSafeGet(ctrls(k), 'Tag')) ' ' cbTxt]);
                if ~isempty(strfind(key, 'bmode')) || ~isempty(strfind(key, 'doppler'))
                    figScore = figScore + 80;
                    break;
                end
            end
        catch
        end

        try
            axesList = findall(hFig, 'Type', 'axes');
        catch
            axesList = [];
        end

        for iAx = 1:numel(axesList)
            ax = axesList(iAx);
            tagAx = '';
            try, tagAx = lower(localAnyToText(get(ax, 'Tag'))); catch, end
            if ~isempty(strfind(tagAx, 'colorbar')) || ~isempty(strfind(tagAx, 'legend')) || ...
                    ~isempty(strfind(tagAx, 'logo')) || ~isempty(strfind(tagAx, 'banner'))
                continue;
            end

            w = 0; h = 0; areaPx = 0;
            try
                pp = getpixelposition(ax, true);
                w = max(0, pp(3));
                h = max(0, pp(4));
                areaPx = w*h;
            catch
            end
            if areaPx <= 0
                continue;
            end

            ratio = w / max(h,1);
            score = figScore + 18*log10(max(1,areaPx));

            % Main imaging axes are usually reasonably square/portrait.
            % The supplied OpenfUS logo is ~450x150 (ratio ~3), so strongly
            % penalize wide banner-like axes instead of rewarding them merely
            % because they already contain an image.
            if ratio > 2.3 || ratio < 0.30
                score = score - 90;
            end
            if h < 180
                score = score - 55;
            end
            if areaPx < 30000
                score = score - 30;
            end

            try
                hImgs = findall(ax, 'Type', 'image');
                for ii = 1:numel(hImgs)
                    cd = get(hImgs(ii), 'CData');
                    if isnumeric(cd) && ndims(cd) >= 2
                        rr = size(cd,1); cc = size(cd,2);
                        if (rr <= 220 && cc >= 350 && cc/ max(rr,1) > 2.2)
                            score = score - 120; % likely OpenfUS logo/banner
                        else
                            score = score + 5;   % tiny bonus only
                        end
                    end
                end
            catch
            end

            if score > bestScore
                bestScore = score;
                axBest = ax;
                figBest = hFig;
            end
        end
    end

    if bestScore < 50
        axBest = [];
        figBest = [];
    end
end

function h = localShowHighResPreview(I, cfg, labelTxt, sourceFile)
    % V7 high-resolution anatomy viewer.
    % ------------------------------------------------------------------
    % DISPLAY ONLY: the saved matrix I is never altered by these controls.
    %
    % Neutral/default appearance follows the supplied company HR2D demo:
    %       sqrt(sqrt(sqrt(Ihq)))  -> 1/8-power dynamic-range compression
    %       gray colormap          -> MATLAB caxis auto equivalent
    %
    % V5 adds optional display-only controls inspired by deConfUSIon-style
    % viewing: black/white level, gain, gamma, logarithmic compression and
    % unsharp-mask sharpness. All are neutral on opening, so RESET COMPANY
    % always returns to the vendor-demo appearance.

    h = [];
    try
        if isempty(I) || ~isnumeric(I)
            return;
        end
        if nargin < 3 || isempty(labelTxt)
            labelTxt = 'High-Res';
        end
        if nargin < 4
            sourceFile = '';
        end

        vol = squeeze(I);
        is3D = ndims(vol) >= 3 && size(vol,3) > 1;
        if is3D
            nSlices = size(vol,3);
            midSlice = max(1, round((nSlices+1)/2));
        else
            nSlices = 1;
            midSlice = 1;
        end

        [companyMin, companyMax] = localHighResCompanyLimits(vol);

        tagTxt = ['vfUSI_' strrep(labelTxt,' ','_') '_Viewer'];
        old = findobj(0, 'Type', 'figure', 'Tag', tagTxt);
        if isempty(old) || ~ishandle(old(1))
            h = figure( ...
                'Name', ['OpenfUS - ' labelTxt ' Anatomy Viewer'], ...
                'NumberTitle', 'off', ...
                'Tag', tagTxt, ...
                'Color', [0.05 0.05 0.06], ...
                'Position', [90 45 1320 845]);
        else
            h = old(1);
            figure(h);
            clf(h);
        end

        ax = axes('Parent', h, ...
            'Units', 'normalized', ...
            'Position', [0.045 0.145 0.64 0.80], ...
            'Color', 'k');

        p = uipanel(h, 'Units', 'normalized', ...
            'Position', [0.710 0.055 0.275 0.89], ...
            'Title', 'Display (saved data stays unchanged)', ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'ForegroundColor', 'w', ...
            'BackgroundColor', [0.09 0.09 0.10]);

        y = 0.925;
        hBlackTxt = localViewerSliderLabel(p, 'Black level', '0 %', y);
        sBlack = localViewerSlider(p, 0, 0.90, 0, y-0.045);
        y = y - 0.105;
        hWhiteTxt = localViewerSliderLabel(p, 'White level', '100 %', y);
        sWhite = localViewerSlider(p, 0.10, 1.00, 1.00, y-0.045);
        y = y - 0.105;
        hGainTxt = localViewerSliderLabel(p, 'Gain', '1.00 x', y);
        sGain = localViewerSlider(p, 0.25, 4.00, 1.00, y-0.045);
        y = y - 0.105;
        hGammaTxt = localViewerSliderLabel(p, 'Gamma', '1.00', y);
        sGamma = localViewerSlider(p, 0.25, 3.00, 1.00, y-0.045);
        y = y - 0.105;
        hLogTxt = localViewerSliderLabel(p, 'Log compression', 'Off', y);
        sLog = localViewerSlider(p, 0, 1, 0, y-0.045);
        y = y - 0.105;
        hSharpTxt = localViewerSliderLabel(p, 'Sharpness', 'Off', y);
        sSharp = localViewerSlider(p, 0, 2, 0, y-0.045);

        uicontrol(p, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.08 0.275 0.32 0.035], 'String', 'Colormap', ...
            'HorizontalAlignment', 'left', 'FontSize', 9, ...
            'ForegroundColor', 'w', 'BackgroundColor', [0.09 0.09 0.10]);
        pMap = uicontrol(p, 'Style', 'popupmenu', 'Units', 'normalized', ...
            'Position', [0.40 0.270 0.52 0.045], ...
            'String', {'Gray','Hot'}, 'Value', 1, 'FontSize', 10, ...
            'BackgroundColor', 'w');

        uicontrol(p, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.08 0.220 0.25 0.035], 'String', 'Grid rows', ...
            'HorizontalAlignment', 'left', 'FontSize', 9, ...
            'ForegroundColor', 'w', 'BackgroundColor', [0.09 0.09 0.10]);
        pRows = uicontrol(p, 'Style', 'popupmenu', 'Units', 'normalized', ...
            'Position', [0.30 0.215 0.18 0.045], ...
            'String', arrayfun(@num2str,1:8,'UniformOutput',false), ...
            'Value', 4, 'BackgroundColor', 'w');
        uicontrol(p, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.52 0.220 0.22 0.035], 'String', 'Grid cols', ...
            'HorizontalAlignment', 'left', 'FontSize', 9, ...
            'ForegroundColor', 'w', 'BackgroundColor', [0.09 0.09 0.10]);
        pCols = uicontrol(p, 'Style', 'popupmenu', 'Units', 'normalized', ...
            'Position', [0.74 0.215 0.18 0.045], ...
            'String', arrayfun(@num2str,1:8,'UniformOutput',false), ...
            'Value', 4, 'BackgroundColor', 'w');

        bReset = uicontrol(p, 'Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [0.08 0.145 0.84 0.052], ...
            'String', 'RESET COMPANY DEFAULT', ...
            'FontSize', 9, 'FontWeight', 'bold');
        bGrid = uicontrol(p, 'Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [0.08 0.085 0.40 0.050], ...
            'String', 'GRID', 'FontSize', 10, 'FontWeight', 'bold');
        bSave = uicontrol(p, 'Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [0.52 0.085 0.40 0.050], ...
            'String', 'SAVE VIEW', 'FontSize', 10, 'FontWeight', 'bold');
        hInfo = uicontrol(p, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.08 0.010 0.84 0.065], 'String', '', ...
            'HorizontalAlignment', 'left', 'FontSize', 8.5, ...
            'ForegroundColor', [0.88 0.88 0.90], ...
            'BackgroundColor', [0.09 0.09 0.10]);

        hSlider = uicontrol(h, 'Style', 'slider', 'Units', 'normalized', ...
            'Position', [0.075 0.070 0.50 0.045], ...
            'Min', 1, 'Max', max(1,nSlices), 'Value', midSlice);
        hSliceTxt = uicontrol(h, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.585 0.064 0.10 0.055], ...
            'String', sprintf('%d / %d', midSlice, nSlices), ...
            'FontSize', 12, 'FontWeight', 'bold', ...
            'ForegroundColor', 'w', 'BackgroundColor', [0.05 0.05 0.06]);
        hHint = uicontrol(h, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.045 0.012 0.64 0.038], ...
            'String', 'Default = company demo (1/8-power, gray, per-slice auto). Wheel/arrows change 3D slice.', ...
            'FontSize', 9, 'HorizontalAlignment', 'left', ...
            'ForegroundColor', [0.78 0.80 0.84], 'BackgroundColor', [0.05 0.05 0.06]); %#ok<NASGU>

        if is3D && nSlices > 1
            set(hSlider, 'SliderStep', [1/(nSlices-1), min(10/(nSlices-1),1)]);
        else
            set(hSlider, 'Enable', 'off', 'Visible', 'off');
            set(hSliceTxt, 'String', '2D');
        end

        V = struct();
        V.volume = vol;
        V.ax = ax;
        V.slider = hSlider;
        V.sliceText = hSliceTxt;
        V.label = labelTxt;
        V.currentSlice = midSlice;
        V.nSlices = nSlices;
        V.is3D = is3D;
        V.companyMin = companyMin;
        V.companyMax = companyMax;
        V.blackLevel = 0;
        V.whiteLevel = 1;
        V.gain = 1;
        V.gamma = 1;
        V.logStrength = 0;
        V.sharpness = 0;
        V.colormapName = 'gray';
        V.gridRows = 4;
        V.gridCols = 4;
        V.sBlack = sBlack; V.sWhite = sWhite; V.sGain = sGain;
        V.sGamma = sGamma; V.sLog = sLog; V.sSharp = sSharp;
        V.hBlackTxt = hBlackTxt; V.hWhiteTxt = hWhiteTxt;
        V.hGainTxt = hGainTxt; V.hGammaTxt = hGammaTxt;
        V.hLogTxt = hLogTxt; V.hSharpTxt = hSharpTxt;
        V.pMap = pMap; V.pRows = pRows; V.pCols = pCols;
        V.infoText = hInfo;
        V.savedFile = sourceFile;
        V.logFcn = [];
        try
            if isfield(cfg,'gui') && isstruct(cfg.gui) && isfield(cfg.gui,'logFcn')
                V.logFcn = cfg.gui.logFcn;
            end
        catch
        end
        setappdata(h, 'vfUSI_HRViewer', V);

        % Immediate diagnostics distinguish a display problem from an empty
        % reconstruction. These values are only logged; data are not changed.
        try
            rawv = double(vol(:));
            rawv = rawv(isfinite(rawv));
            if isempty(rawv)
                localViewerLog(V, 'HR data diagnostic: no finite voxels.');
            else
                localViewerLog(V, sprintf('HR data diagnostic: raw min=%g max=%g absmax=%g size=%s.', ...
                    min(rawv), max(rawv), max(abs(rawv)), mat2str(size(vol))));
            end
        catch MEstat
            localViewerLog(V, ['HR data diagnostic warning: ' MEstat.message]);
        end

        allSliders = [sBlack sWhite sGain sGamma sLog sSharp];
        for ii = 1:numel(allSliders)
            set(allSliders(ii), 'Callback', @(src,evt)localHighResControlsChanged(h));
        end
        set(pMap, 'Callback', @(src,evt)localHighResControlsChanged(h));
        set(pRows, 'Callback', @(src,evt)localHighResControlsChanged(h));
        set(pCols, 'Callback', @(src,evt)localHighResControlsChanged(h));
        set(bReset, 'Callback', @(src,evt)localHighResResetCompany(h));
        set(bGrid, 'Callback', @(src,evt)localHighResShowGrid(h));
        set(bSave, 'Callback', @(src,evt)localHighResSaveView(h));
        set(hSlider, 'Callback', @(src,evt)localHighResSliderChanged(h));
        set(h, 'WindowScrollWheelFcn', @(src,evt)localHighResScroll(h, evt));
        set(h, 'KeyPressFcn', @(src,evt)localHighResKeyPress(h, evt));

        localHighResUpdateViewer(h, midSlice);
        localViewerLog(V, sprintf('%s anatomy viewer opened: reconstructed size %s.', ...
            labelTxt, mat2str(size(vol))));
    catch MEprev
        localGuiLog(cfg, [labelTxt ' viewer warning: ' MEprev.message]);
        h = [];
    end
end

function hTxt = localViewerSliderLabel(parent, labelTxt, valueTxt, y)
    hTxt = uicontrol(parent, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.08 y 0.84 0.035], ...
        'String', [labelTxt '   ' valueTxt], ...
        'HorizontalAlignment', 'left', 'FontSize', 9.5, ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.09 0.09 0.10]);
end

function h = localViewerSlider(parent, mn, mx, val, y)
    h = uicontrol(parent, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.08 y 0.84 0.035], 'Min', mn, 'Max', mx, 'Value', val);
end

function localHighResSliderChanged(hFig)
    try
        V = getappdata(hFig, 'vfUSI_HRViewer');
        localHighResUpdateViewer(hFig, round(get(V.slider, 'Value')));
    catch
    end
end

function localHighResScroll(hFig, evt)
    try
        V = getappdata(hFig, 'vfUSI_HRViewer');
        if ~V.is3D, return; end
        step = 1;
        try, step = evt.VerticalScrollCount; catch, end
        localHighResUpdateViewer(hFig, V.currentSlice + step);
    catch
    end
end

function localHighResKeyPress(hFig, evt)
    try
        V = getappdata(hFig, 'vfUSI_HRViewer');
        if ~V.is3D, return; end
        key = lower(evt.Key);
        if strcmp(key,'rightarrow') || strcmp(key,'uparrow')
            idx = V.currentSlice + 1;
        elseif strcmp(key,'leftarrow') || strcmp(key,'downarrow')
            idx = V.currentSlice - 1;
        elseif strcmp(key,'home')
            idx = 1;
        elseif strcmp(key,'end')
            idx = V.nSlices;
        else
            return;
        end
        localHighResUpdateViewer(hFig, idx);
    catch
    end
end

function localHighResControlsChanged(hFig)
    try
        V = getappdata(hFig, 'vfUSI_HRViewer');
        V.blackLevel = get(V.sBlack, 'Value');
        V.whiteLevel = get(V.sWhite, 'Value');
        if V.whiteLevel <= V.blackLevel + 0.01
            V.whiteLevel = min(1, V.blackLevel + 0.01);
            set(V.sWhite, 'Value', V.whiteLevel);
        end
        V.gain = get(V.sGain, 'Value');
        V.gamma = get(V.sGamma, 'Value');
        V.logStrength = get(V.sLog, 'Value');
        V.sharpness = get(V.sSharp, 'Value');

        maps = get(V.pMap, 'String');
        V.colormapName = lower(maps{get(V.pMap,'Value')});
        V.gridRows = get(V.pRows, 'Value');
        V.gridCols = get(V.pCols, 'Value');

        set(V.hBlackTxt, 'String', sprintf('Black level   %.0f %%', 100*V.blackLevel));
        set(V.hWhiteTxt, 'String', sprintf('White level   %.0f %%', 100*V.whiteLevel));
        set(V.hGainTxt, 'String', sprintf('Gain   %.2f x', V.gain));
        set(V.hGammaTxt, 'String', sprintf('Gamma   %.2f', V.gamma));
        if V.logStrength < 0.01
            set(V.hLogTxt, 'String', 'Log compression   Off');
        else
            set(V.hLogTxt, 'String', sprintf('Log compression   %.0f %%',100*V.logStrength));
        end
        if V.sharpness < 0.01
            set(V.hSharpTxt, 'String', 'Sharpness   Off');
        else
            set(V.hSharpTxt, 'String', sprintf('Sharpness   %.2f',V.sharpness));
        end

        setappdata(hFig, 'vfUSI_HRViewer', V);
        localHighResUpdateViewer(hFig, V.currentSlice);
    catch ME
        try
            V = getappdata(hFig, 'vfUSI_HRViewer');
            localViewerLog(V, ['Display control error: ' ME.message]);
        catch
        end
    end
end

function localHighResResetCompany(hFig)
    try
        V = getappdata(hFig, 'vfUSI_HRViewer');
        V.blackLevel = 0; V.whiteLevel = 1; V.gain = 1; V.gamma = 1;
        V.logStrength = 0; V.sharpness = 0; V.colormapName = 'gray';
        set(V.sBlack,'Value',0); set(V.sWhite,'Value',1);
        set(V.sGain,'Value',1); set(V.sGamma,'Value',1);
        set(V.sLog,'Value',0); set(V.sSharp,'Value',0);
        set(V.pMap,'Value',1);
        set(V.hBlackTxt,'String','Black level   0 %');
        set(V.hWhiteTxt,'String','White level   100 %');
        set(V.hGainTxt,'String','Gain   1.00 x');
        set(V.hGammaTxt,'String','Gamma   1.00');
        set(V.hLogTxt,'String','Log compression   Off');
        set(V.hSharpTxt,'String','Sharpness   Off');
        setappdata(hFig,'vfUSI_HRViewer',V);
        localHighResUpdateViewer(hFig,V.currentSlice);
        localViewerLog(V,'Display reset to supplied company HR demo default.');
    catch
    end
end

function localHighResUpdateViewer(hFig, idx)
    V = getappdata(hFig, 'vfUSI_HRViewer');
    idx = max(1, min(V.nSlices, round(idx)));
    V.currentSlice = idx;

    if V.is3D
        img = squeeze(V.volume(:,:,idx));
    else
        img = squeeze(V.volume);
    end
    imgDisp = localHighResDisplayTransform(img, V);

    hImgs = findall(V.ax, 'Type', 'image');
    if isempty(hImgs)
        imagesc(V.ax, imgDisp, [0 1]);
        axis(V.ax, 'image'); axis(V.ax, 'tight');
        colorbar('peer', V.ax);
    else
        set(hImgs(1), 'CData', imgDisp);
        set(V.ax, 'CLim', [0 1]);
    end

    if strcmpi(V.colormapName, 'hot')
        colormap(V.ax, hot(256));
    else
        colormap(V.ax, gray(256));
    end

    if V.is3D
        title(V.ax, sprintf('%s anatomy - slice %d / %d', V.label, idx, V.nSlices), ...
            'Interpreter','none','Color','w');
        set(V.slider,'Value',idx);
        set(V.sliceText,'String',sprintf('%d / %d',idx,V.nSlices));
    else
        title(V.ax,[V.label ' anatomy'],'Interpreter','none','Color','w');
    end
    set(V.ax,'XColor','w','YColor','w','Color','k');

    if isempty(V.savedFile)
        fileTxt = 'Not saved yet';
    else
        [~,base,ext] = fileparts(V.savedFile);
        fileTxt = [base ext];
    end
    set(V.infoText,'String',sprintf('Slices %d | Grid %dx%d | %s', ...
        V.nSlices,V.gridRows,V.gridCols,fileTxt));
    setappdata(hFig,'vfUSI_HRViewer',V);
    drawnow;
end

function localHighResShowGrid(hViewer)
    try
        localHighResControlsChanged(hViewer);
        V = getappdata(hViewer,'vfUSI_HRViewer');
        if ~V.is3D
            localViewerLog(V,'GRID is only needed for 3D anatomy.');
            return;
        end
        nWanted = max(1,V.gridRows*V.gridCols);
        idxList = unique(round(linspace(1,V.nSlices,min(nWanted,V.nSlices))));
        tagGrid = [get(hViewer,'Tag') '_Grid'];
        old = findobj(0,'Type','figure','Tag',tagGrid);
        if isempty(old) || ~ishandle(old(1))
            hGridFig = figure('Name',['OpenfUS - ' V.label ' Anatomy Grid'], ...
                'NumberTitle','off','Tag',tagGrid,'Color','k','Position',[60 40 1350 900]);
        else
            hGridFig = old(1); figure(hGridFig); clf(hGridFig);
        end
        for k = 1:numel(idxList)
            figure(hGridFig);
            ax = subplot(V.gridRows,V.gridCols,k);
            img = squeeze(V.volume(:,:,idxList(k)));
            imagesc(ax,localHighResDisplayTransform(img,V),[0 1]);
            axis(ax,'image'); axis(ax,'off');
            title(ax,sprintf('%d/%d',idxList(k),V.nSlices),'Color','w','FontSize',8);
        end
        if strcmpi(V.colormapName,'hot'), colormap(hGridFig,hot(256)); else, colormap(hGridFig,gray(256)); end
        drawnow;
    catch ME
        try, V=getappdata(hViewer,'vfUSI_HRViewer'); localViewerLog(V,['Grid warning: ' ME.message]); catch, end
    end
end

function localHighResSaveView(hViewer)
    try
        localHighResControlsChanged(hViewer);
        V = getappdata(hViewer,'vfUSI_HRViewer');
        if isempty(V.savedFile)
            localViewerLog(V,'SAVE VIEW unavailable because this anatomy was not saved.');
            return;
        end
        [folderPath,baseName,~] = fileparts(V.savedFile);
        display_settings = struct(); %#ok<NASGU>
        display_settings.company_default_transform = 'sqrt(sqrt(sqrt(abs(I))))';
        display_settings.black_level = V.blackLevel;
        display_settings.white_level = V.whiteLevel;
        display_settings.gain = V.gain;
        display_settings.gamma = V.gamma;
        display_settings.log_strength = V.logStrength;
        display_settings.sharpness = V.sharpness;
        display_settings.colormap = V.colormapName;
        display_settings.current_slice = V.currentSlice;
        display_settings.grid_rows = V.gridRows;
        display_settings.grid_cols = V.gridCols;
        display_settings.source_anatomy_file = V.savedFile;
        display_settings.saved_at = datestr(now,'yyyy-mm-dd HH:MM:SS');
        settingsFile = fullfile(folderPath,[baseName '_display.mat']);
        previewFile = fullfile(folderPath,[baseName '_preview.png']);
        save(settingsFile,'display_settings','-v7');
        try
            print(hViewer,previewFile,'-dpng','-r150');
        catch
            try
                saveas(hViewer,previewFile);
            catch
            end
        end
        localViewerLog(V,sprintf('Saved viewer settings: %s | preview: %s',settingsFile,previewFile));
    catch ME
        try, V=getappdata(hViewer,'vfUSI_HRViewer'); localViewerLog(V,['SAVE VIEW failed: ' ME.message]); catch, end
    end
end

function localHighResAttachSavedFile(hViewer, nameFile)
    try
        if isempty(hViewer) || ~ishandle(hViewer), return; end
        V = getappdata(hViewer,'vfUSI_HRViewer');
        V.savedFile = nameFile;
        setappdata(hViewer,'vfUSI_HRViewer',V);
        localHighResUpdateViewer(hViewer,V.currentSlice);
        localViewerLog(V,['Anatomy saved as ' nameFile]);
    catch
    end
end

function out = localHighResDisplayTransform(img, V)
    % V7 company-like per-displayed-image default with signed/complex rescue.
    % The supplied HR2D demo applies sqrt(sqrt(sqrt(Ihq))) and then
    % caxis('auto') to THAT image. V5 instead used one global min/max for an
    % entire HR3D volume; a few bright slices/outliers could therefore make
    % the currently viewed slice almost completely black.
    %
    % V7 computes the company auto range separately for each displayed slice
    % (and separately for each grid tile), then applies the optional sliders.
    x = localHighResCompanyTransform(img);
    [mn,mx] = localHighResCompanyLimits(img);
    den = mx-mn;
    if ~isfinite(den) || den<=0, den=1; end
    out = (x-mn)./den;
    out(out<0)=0; out(out>1)=1;

    lo = V.blackLevel; hi = V.whiteLevel;
    if hi <= lo + 1e-6, hi = lo + 1e-6; end
    out = (out-lo)./(hi-lo);
    out(out<0)=0; out(out>1)=1;

    out = out .* V.gain;
    out(out<0)=0; out(out>1)=1;
    g = V.gamma; if ~isfinite(g) || g<=0, g=1; end
    out = out .^(1./g);

    ls = V.logStrength;
    if isfinite(ls) && ls > 0.001
        a = 1 + 99*ls;
        out = log1p(a*out) ./ log1p(a);
    end

    sh = V.sharpness;
    if isfinite(sh) && sh > 0.001 && ismatrix(out)
        ker = [1 2 1; 2 4 2; 1 2 1] / 16;
        blur = conv2(out,ker,'same');
        out = out + sh.*(out-blur);
        out(out<0)=0; out(out>1)=1;
    end
end

function x = localHighResCompanyTransform(img)
    % Display magnitude is intentionally used for robustness. For normal
    % company HR2D data (which are already non-negative) abs() is a no-op.
    % For HR3D reconstructions containing signed/complex values it prevents
    % an otherwise completely black display while leaving saved I untouched.
    x = abs(double(img));
    x(~isfinite(x)) = 0;
    % Exact dynamic-range compression shown in the supplied company HR2D demo.
    x = sqrt(sqrt(sqrt(x)));
end

function [mn,mx] = localHighResCompanyLimits(data)
    x = localHighResCompanyTransform(data);
    x = x(:); x = x(isfinite(x));
    if isempty(x), mn=0; mx=1; return; end
    if numel(x) > 500000
        idx = round(linspace(1,numel(x),500000));
        x = x(idx);
    end

    % Start with the company-style automatic full range.
    mn = min(x); mx = max(x);
    if ~isfinite(mn), mn=0; end
    if ~isfinite(mx) || mx<=mn, mx=mn+1; return; end

    % Adaptive rescue for sparse HR3D outliers. If >99 %% of pixels would
    % occupy the bottom 1 %% of the full range, the mathematically correct
    % caxis-auto view is visually almost black. In that pathological case
    % use robust percentiles for DISPLAY ONLY. Ordinary vendor HR data stay
    % on the exact min/max path above.
    try
        y = (x-mn) ./ max(eps,mx-mn);
        if mean(y < 0.01) > 0.99
            xs = sort(x);
            n = numel(xs);
            iLo = max(1, round(0.002*n));
            iHi = min(n, max(iLo+1, round(0.998*n)));
            mn2 = xs(iLo); mx2 = xs(iHi);
            if isfinite(mn2) && isfinite(mx2) && mx2 > mn2
                mn = mn2; mx = mx2;
            end
        end
    catch
    end
end

function localViewerLog(V, msg)
    try
        if isfield(V,'logFcn') && ~isempty(V.logFcn) && isa(V.logFcn,'function_handle')
            V.logFcn(msg);
        else
            fprintf('[HR Viewer] %s\n', msg);
        end
    catch
        try
            fprintf('[HR Viewer] %s\n', msg);
        catch
        end
    end
end

function localLogHighResMetadataMode(cfg, md)
    try
        if isstruct(md) && isfield(md, 'highres_metadata_source')
            localGuiLog(cfg, ['High-res metadata source: ' localSafeText(md.highres_metadata_source)]);
        end
    catch
    end
    % V13: always surface the actual HR signal diagnostics in the main Live
    % Log.  If recon absmax is zero, the black HR viewer is not a slider/GUI
    % problem and should not be disguised with artificial display scaling.
    try
        sf=NaN;sa=NaN;ra=NaN;rn=NaN;rp='unknown';
        if isfield(md,'highres_nframes_used'),sf=double(md.highres_nframes_used);end
        if isfield(md,'highres_spec_absmax'),sa=double(md.highres_spec_absmax);end
        if isfield(md,'highres_recon_absmax'),ra=double(md.highres_recon_absmax);end
        if isfield(md,'highres_recon_nonzero_fraction'),rn=100*double(md.highres_recon_nonzero_fraction);end
        if isfield(md,'highres_reconstruction_path'),rp=localSafeText(md.highres_reconstruction_path);end
        localGuiLog(cfg,sprintf('HR diagnostic: source=%g | spec absmax=%g | recon absmax=%g | recon nonzero=%.5g%% | %s', ...
            sf,sa,ra,rn,rp));
    catch
    end
end

function mode = localGetImagingMode(cfg)
    mode = 'doppler';
    try
        if isfield(cfg, 'acquisition_mode') && ischar(cfg.acquisition_mode) && ...
                ~isempty(strtrim(cfg.acquisition_mode))
            mode = lower(strtrim(cfg.acquisition_mode));
        end
    catch
        mode = 'doppler';
    end

    mode = strrep(mode, '-', '');
    mode = strrep(mode, '_', '');
    mode = strrep(mode, ' ', '');

    switch mode
        case {'doppler','normal'}
            mode = 'doppler';
        case {'functional','functionalfusi','functionaltime','functionaltimeseries','timeseries','fusitime'}
            mode = 'functional';
        case {'bmode','bmodelive','livebmode'}
            mode = 'bmode_live';
        case {'highres2d','hr2d','highresolution2d'}
            mode = 'highres2d';
        case {'highres3d','hr3d','highresolution3d'}
            mode = 'highres3d';
        otherwise
            % Keep unknown string so validation can report it clearly.
    end
end


% =========================================================================
% Defaults
% =========================================================================
function cfg = localApplyDefaults(cfg)

    if ~isfield(cfg, 'xp_name') || isempty(cfg.xp_name)
        cfg.xp_name = 'Data_w_Triggers';
    end

    % HUMOR_OUTPUT_ROOT_CDATA_DEFAULT_V1
    % Default acquisition output root.
    if ~isfield(cfg, 'output_root') || isempty(cfg.output_root)
        cfg.output_root = 'C:\Data';
    end

    if ~isfield(cfg, 'n_frames') || isempty(cfg.n_frames)
        cfg.n_frames = 9000;
    end

    if ~isfield(cfg, 'nblocksImage') || isempty(cfg.nblocksImage)
        cfg.nblocksImage = 16;
    end

    if ~isfield(cfg, 'acquisition_mode') || isempty(cfg.acquisition_mode) || ...
            ~ischar(cfg.acquisition_mode)
        cfg.acquisition_mode = 'doppler';
    end
    cfg.acquisition_mode = localGetImagingMode(cfg);

    % ---------------- Probe type ----------------
    % '2D' = linear probe, TR unit 0.02 s per nblocksImage
    % '3D' = volumetric probe, TR unit 0.03 s per nblocksImage
    if ~isfield(cfg, 'probe_type') || isempty(cfg.probe_type) || ~ischar(cfg.probe_type)
        cfg.probe_type = '2D';
    end

    if ~isempty(strfind(upper(cfg.probe_type), '3D'))
        cfg.probe_type = '3D';
        defaultTRUnit = 0.03;
    else
        cfg.probe_type = '2D';
        defaultTRUnit = 0.02;
    end

    if ~isfield(cfg, 'tr_unit_s') || isempty(cfg.tr_unit_s) || ...
            ~isnumeric(cfg.tr_unit_s) || ~isfinite(cfg.tr_unit_s) || cfg.tr_unit_s <= 0
        cfg.tr_unit_s = defaultTRUnit;
    end

    % Company high-resolution helpers use fixed sequence settings.
    if strcmpi(cfg.acquisition_mode, 'highres2d')
        cfg.probe_type = '2D';
        cfg.tr_unit_s = 0.02;
        cfg.nblocksImage = 10;
    elseif strcmpi(cfg.acquisition_mode, 'highres3d')
        cfg.probe_type = '3D';
        cfg.tr_unit_s = 0.03;
        cfg.nblocksImage = 17;
    end

    if ~isfield(cfg, 'n_trials') || isempty(cfg.n_trials)
        cfg.n_trials = 1;
    end

    if ~isfield(cfg, 'time_pause') || isempty(cfg.time_pause)
        cfg.time_pause = 1;
    end

    if ~isfield(cfg, 'stim_start') || isempty(cfg.stim_start)
        cfg.stim_start = NaN;
    end

    if ~isfield(cfg, 'stim_duration') || isempty(cfg.stim_duration)
        cfg.stim_duration = NaN;
    end

    % ---------------- StimBox ----------------
    if ~isfield(cfg, 'stimbox') || ~isstruct(cfg.stimbox)
        cfg.stimbox = struct();
    end

    if ~isfield(cfg.stimbox, 'enable') || isempty(cfg.stimbox.enable)
        cfg.stimbox.enable = false;
    end

    if ~isfield(cfg.stimbox, 'com') || isempty(cfg.stimbox.com)
        cfg.stimbox.com = 'COM9';
    end

    if ~isfield(cfg.stimbox, 'baud') || isempty(cfg.stimbox.baud)
        cfg.stimbox.baud = 9600;
    end

    if ~isfield(cfg.stimbox, 'verbose') || isempty(cfg.stimbox.verbose)
        cfg.stimbox.verbose = true;
    end

    if ~isfield(cfg.stimbox, 'start_frame') || isempty(cfg.stimbox.start_frame)
        cfg.stimbox.start_frame = 20;
    end

    if ~isfield(cfg.stimbox, 'frame_duration') || isempty(cfg.stimbox.frame_duration)
        cfg.stimbox.frame_duration = 10;
    end

    if ~isfield(cfg.stimbox, 'repeat_enable') || isempty(cfg.stimbox.repeat_enable)
        cfg.stimbox.repeat_enable = true;
    end

    if ~isfield(cfg.stimbox, 'repeat_interval_frames') || isempty(cfg.stimbox.repeat_interval_frames)
        cfg.stimbox.repeat_interval_frames = 50;
    end

    if ~isfield(cfg.stimbox, 'd3_enable') || isempty(cfg.stimbox.d3_enable)
        cfg.stimbox.d3_enable = false;
    end

    if ~isfield(cfg.stimbox, 'd5_enable') || isempty(cfg.stimbox.d5_enable)
        cfg.stimbox.d5_enable = true;
    end

    if ~isfield(cfg.stimbox, 'd6_enable') || isempty(cfg.stimbox.d6_enable)
        cfg.stimbox.d6_enable = false;
    end

    if ~isfield(cfg.stimbox, 'd3_trig') || isempty(cfg.stimbox.d3_trig)
        cfg.stimbox.d3_trig = NaN;
    end

    if ~isfield(cfg.stimbox, 'd5_trig') || isempty(cfg.stimbox.d5_trig)
        cfg.stimbox.d5_trig = NaN;
    end

    if ~isfield(cfg.stimbox, 'd6_trig') || isempty(cfg.stimbox.d6_trig)
        cfg.stimbox.d6_trig = NaN;
    end

    % ---------------- PulsePal ----------------
    if ~isfield(cfg, 'pulsepal') || ~isstruct(cfg.pulsepal)
        cfg.pulsepal = struct();
    end

    if ~isfield(cfg.pulsepal, 'enable') || isempty(cfg.pulsepal.enable)
        cfg.pulsepal.enable = false;
    end

    if ~isfield(cfg.pulsepal, 'com') || isempty(cfg.pulsepal.com)
        cfg.pulsepal.com = 'COM14';
    end

    if ~isfield(cfg.pulsepal, 'channel') || isempty(cfg.pulsepal.channel)
        cfg.pulsepal.channel = 1;
    end

    if ~isfield(cfg.pulsepal, 'start_frame') || isempty(cfg.pulsepal.start_frame)
        cfg.pulsepal.start_frame = 100;
    end

    if ~isfield(cfg.pulsepal, 'frame_duration') || isempty(cfg.pulsepal.frame_duration)
        cfg.pulsepal.frame_duration = 1;
    end

    if ~isfield(cfg.pulsepal, 'repeat_enable') || isempty(cfg.pulsepal.repeat_enable)
        cfg.pulsepal.repeat_enable = false;
    end

    if ~isfield(cfg.pulsepal, 'repeat_interval_frames') || isempty(cfg.pulsepal.repeat_interval_frames)
        cfg.pulsepal.repeat_interval_frames = 10;
    end

    if ~isfield(cfg.pulsepal, 'is_biphasic') || isempty(cfg.pulsepal.is_biphasic)
        cfg.pulsepal.is_biphasic = false;
    end
    if ~isfield(cfg.pulsepal, 'phase1_voltage') || isempty(cfg.pulsepal.phase1_voltage)
        cfg.pulsepal.phase1_voltage = 5;
    end
    if ~isfield(cfg.pulsepal, 'phase1_duration_s') || isempty(cfg.pulsepal.phase1_duration_s)
        cfg.pulsepal.phase1_duration_s = 0.005;
    end
    if ~isfield(cfg.pulsepal, 'interphase_interval_s') || isempty(cfg.pulsepal.interphase_interval_s)
        cfg.pulsepal.interphase_interval_s = 0.0001;
    end
    if ~isfield(cfg.pulsepal, 'phase2_voltage') || isempty(cfg.pulsepal.phase2_voltage)
        cfg.pulsepal.phase2_voltage = -5;
    end
    if ~isfield(cfg.pulsepal, 'phase2_duration_s') || isempty(cfg.pulsepal.phase2_duration_s)
        cfg.pulsepal.phase2_duration_s = 0.005;
    end
    if ~isfield(cfg.pulsepal, 'resting_voltage') || isempty(cfg.pulsepal.resting_voltage)
        cfg.pulsepal.resting_voltage = 0;
    end
    if ~isfield(cfg.pulsepal, 'interpulse_interval_s') || isempty(cfg.pulsepal.interpulse_interval_s)
        cfg.pulsepal.interpulse_interval_s = 0.050;
    end
    if ~isfield(cfg.pulsepal, 'burst_duration_s') || isempty(cfg.pulsepal.burst_duration_s)
        cfg.pulsepal.burst_duration_s = 0;
    end
    if ~isfield(cfg.pulsepal, 'interburst_interval_s') || isempty(cfg.pulsepal.interburst_interval_s)
        cfg.pulsepal.interburst_interval_s = 0.100;
    end
    if ~isfield(cfg.pulsepal, 'train_delay_s') || isempty(cfg.pulsepal.train_delay_s)
        cfg.pulsepal.train_delay_s = 0;
    end
    if ~isfield(cfg.pulsepal, 'train_duration_s') || isempty(cfg.pulsepal.train_duration_s)
        cfg.pulsepal.train_duration_s = 0.500;
    end
    if ~isfield(cfg.pulsepal, 'custom_train_id') || isempty(cfg.pulsepal.custom_train_id)
        cfg.pulsepal.custom_train_id = 0;
    end
    if ~isfield(cfg.pulsepal, 'custom_train_target') || isempty(cfg.pulsepal.custom_train_target)
        cfg.pulsepal.custom_train_target = 0;
    end
    if ~isfield(cfg.pulsepal, 'custom_train_loop') || isempty(cfg.pulsepal.custom_train_loop)
        cfg.pulsepal.custom_train_loop = false;
    end
    if ~isfield(cfg.pulsepal, 'link_trigger_ch1') || isempty(cfg.pulsepal.link_trigger_ch1)
        cfg.pulsepal.link_trigger_ch1 = false;
    end
    if ~isfield(cfg.pulsepal, 'link_trigger_ch2') || isempty(cfg.pulsepal.link_trigger_ch2)
        cfg.pulsepal.link_trigger_ch2 = false;
    end
    if ~isfield(cfg.pulsepal, 'trigger_mode1') || isempty(cfg.pulsepal.trigger_mode1)
        cfg.pulsepal.trigger_mode1 = 0;
    end
    if ~isfield(cfg.pulsepal, 'trigger_mode2') || isempty(cfg.pulsepal.trigger_mode2)
        cfg.pulsepal.trigger_mode2 = 0;
    end

    % ---------------- Motor ----------------
    if ~isfield(cfg, 'motor') || ~isstruct(cfg.motor)
        cfg.motor = struct();
    end

    if ~isfield(cfg.motor, 'enable') || isempty(cfg.motor.enable)
        cfg.motor.enable = true;
    end
if ~isfield(cfg.motor, 'acquisition_mode') || isempty(cfg.motor.acquisition_mode)
    cfg.motor.acquisition_mode = 'split';
end

if ~strcmpi(cfg.motor.acquisition_mode, 'continuous') && ~strcmpi(cfg.motor.acquisition_mode, 'split')
    error('cfg.motor.acquisition_mode must be continuous or split.');
end
    if ~isfield(cfg.motor, 'mode') || isempty(cfg.motor.mode)
        cfg.motor.mode = 'stepped';
    end

    if ~isfield(cfg.motor, 'com') || isempty(cfg.motor.com)
        cfg.motor.com = 'COM8';
    end

    if ~isfield(cfg.motor, 'frame_start') || isempty(cfg.motor.frame_start)
        cfg.motor.frame_start = 1;
    end

    if ~isfield(cfg.motor, 'frame_duration') || isempty(cfg.motor.frame_duration)
        cfg.motor.frame_duration = cfg.n_frames;
    end

    if ~isfield(cfg.motor, 'repeat_enable') || isempty(cfg.motor.repeat_enable)
        cfg.motor.repeat_enable = false;
    end

    if ~isfield(cfg.motor, 'repeat_interval_frames') || isempty(cfg.motor.repeat_interval_frames)
        cfg.motor.repeat_interval_frames = 100;
    end

    if ~isfield(cfg.motor, 'start_mm')
        cfg.motor.start_mm = [];
    end
    if ~isfield(cfg.motor, 'end_mm')
        cfg.motor.end_mm = [];
    end

    if ~isfield(cfg.motor, 'start_offset_mm') || isempty(cfg.motor.start_offset_mm)
        cfg.motor.start_offset_mm = -2;
    end

    if ~isfield(cfg.motor, 'end_offset_mm') || isempty(cfg.motor.end_offset_mm)
        cfg.motor.end_offset_mm = 2;
    end

    if ~isfield(cfg.motor, 'step_mm') || isempty(cfg.motor.step_mm)
        cfg.motor.step_mm = 0.5;
    end
if ~isfield(cfg.motor, 'frames_per_position') || isempty(cfg.motor.frames_per_position)
    cfg.motor.frames_per_position = 50;
end

    if ~isfield(cfg.motor, 'periodic') || isempty(cfg.motor.periodic)
        cfg.motor.periodic = false;
    end

    if ~isfield(cfg.motor, 'return_to_zero') || isempty(cfg.motor.return_to_zero)
        cfg.motor.return_to_zero = true;
    end

    if ~isfield(cfg.motor, 'settle_pause_s') || isempty(cfg.motor.settle_pause_s)
        cfg.motor.settle_pause_s = 0.02;  % minimal split-mode motor settling pause
    end

    % ---------------------------------------------------------------------
    % Fast slice pipeline (split mode)
    %
    % When true, the move to the NEXT slice is issued as soon as the current
    % SCAN.doppler call returns, so the stage travels while the current MAT
    % file is being written. The next acquisition then starts as soon as the
    % stage reports idle, instead of after save + move + settle in series.
    % ---------------------------------------------------------------------
    if ~isfield(cfg.motor, 'fast_pipeline') || isempty(cfg.motor.fast_pipeline)
        cfg.motor.fast_pipeline = true;
    end
    cfg.motor.fast_pipeline = logical(cfg.motor.fast_pipeline);

    % In continuous mode, do not block the frame callback while the stage
    % travels. Set false to let imaging continue during the move.
    if ~isfield(cfg.motor, 'wait_until_idle_in_scan') || isempty(cfg.motor.wait_until_idle_in_scan)
        cfg.motor.wait_until_idle_in_scan = false;
    end
    cfg.motor.wait_until_idle_in_scan = logical(cfg.motor.wait_until_idle_in_scan);
end

% =========================================================================
% Backward compatibility bridge
% =========================================================================
function cfg = localApplyBackwardCompatibility(cfg)

    if isfield(cfg, 'stim') && isstruct(cfg.stim) && isfield(cfg.stim, 'device') && ~isempty(cfg.stim.device)
        switch lower(strtrim(cfg.stim.device))
            case 'stimbox'
                if ~isfield(cfg.stimbox, 'enable') || isempty(cfg.stimbox.enable)
                    cfg.stimbox.enable = true;
                end
            case 'pulsepal'
                if ~isfield(cfg.pulsepal, 'enable') || isempty(cfg.pulsepal.enable)
                    cfg.pulsepal.enable = true;
                end
        end
    end

    if isnan(localGetNumericField(cfg.stimbox, {'start_frame','frame_start'}, NaN))
        if isfield(cfg, 'stim_start') && ~isempty(cfg.stim_start) && isnumeric(cfg.stim_start) && ~isnan(cfg.stim_start)
            cfg.stimbox.start_frame = cfg.stim_start;
        end
    end

    if isempty(localGetNumericField(cfg.stimbox, {'frame_duration','duration_frames'}, NaN)) || ...
            isnan(localGetNumericField(cfg.stimbox, {'frame_duration','duration_frames'}, NaN))
        if isfield(cfg, 'stim_duration') && ~isempty(cfg.stim_duration) && isnumeric(cfg.stim_duration) && ~isnan(cfg.stim_duration)
            cfg.stimbox.frame_duration = cfg.stim_duration;
        end
    end

    if isnan(localGetNumericField(cfg.pulsepal, {'start_frame','frame_start'}, NaN))
        if isfield(cfg, 'stim_start') && ~isempty(cfg.stim_start) && isnumeric(cfg.stim_start) && ~isnan(cfg.stim_start)
            cfg.pulsepal.start_frame = cfg.stim_start;
        end
    end

    if isfield(cfg.stimbox, 'd3_trig') && isnumeric(cfg.stimbox.d3_trig) && ~isnan(cfg.stimbox.d3_trig)
        cfg.stimbox.d3_enable = true;
    end
    if isfield(cfg.stimbox, 'd5_trig') && isnumeric(cfg.stimbox.d5_trig) && ~isnan(cfg.stimbox.d5_trig)
        cfg.stimbox.d5_enable = true;
    end
    if isfield(cfg.stimbox, 'd6_trig') && isnumeric(cfg.stimbox.d6_trig) && ~isnan(cfg.stimbox.d6_trig)
        cfg.stimbox.d6_enable = true;
    end

    if isempty(cfg.motor.start_mm)
        cfg.motor.start_mm = localGetNumericField(cfg.motor, {'start_pos_mm','absolute_start_mm'}, []);
    end
    if isempty(cfg.motor.end_mm)
        cfg.motor.end_mm = localGetNumericField(cfg.motor, {'end_pos_mm','absolute_end_mm'}, []);
    end
end

% =========================================================================
% Validation
% =========================================================================
function localValidateConfig(cfg)

    if ~ischar(cfg.xp_name) || isempty(cfg.xp_name)
        error('cfg.xp_name must be a non-empty char array.');
    end

    imagingMode = localGetImagingMode(cfg);
    validImagingModes = {'doppler','functional','bmode_live','highres2d','highres3d'};
    if ~any(strcmpi(imagingMode, validImagingModes))
        error('cfg.acquisition_mode is invalid: %s', cfg.acquisition_mode);
    end

    if strcmpi(imagingMode, 'bmode_live')
        if logical(cfg.stimbox.enable) || logical(cfg.pulsepal.enable) || logical(cfg.motor.enable)
            error(['B-Mode Live is currently preview-only. Disable StimBox, PulsePal and Motor. ' ...
                   'The supplied company files do not expose a B-mode per-frame callback, ' ...
                   'so frame-synchronized TTL cannot be guaranteed safely.']);
        end
    end

    if (strcmpi(imagingMode, 'highres2d') || strcmpi(imagingMode, 'highres3d')) && ...
            logical(cfg.motor.enable)
        error(['High-resolution mode + step motor is intentionally disabled in this patch. ' ...
               'The HR demo defines n_frames per reconstructed image, while split-motor mode ' ...
               'defines n_frames across slice blocks; mixing them would change acquisition semantics.']);
    end

    if ~isscalar(cfg.n_frames) || ~isnumeric(cfg.n_frames) || cfg.n_frames < 1
        error('cfg.n_frames must be a positive scalar.');
    end

    if ~isscalar(cfg.nblocksImage) || ~isnumeric(cfg.nblocksImage) || cfg.nblocksImage < 1
        error('cfg.nblocksImage must be a positive scalar.');
    end

    if ~ischar(cfg.probe_type) || isempty(cfg.probe_type)
        error('cfg.probe_type must be ''2D'' or ''3D''.');
    end

    if ~strcmpi(cfg.probe_type, '2D') && ~strcmpi(cfg.probe_type, '3D')
        error('cfg.probe_type must be ''2D'' or ''3D'', not ''%s''.', cfg.probe_type);
    end

    if ~isscalar(cfg.tr_unit_s) || ~isnumeric(cfg.tr_unit_s) || ...
            ~isfinite(cfg.tr_unit_s) || cfg.tr_unit_s <= 0
        error('cfg.tr_unit_s must be a positive scalar (0.02 for 2D, 0.03 for 3D).');
    end

    if ~isscalar(cfg.n_trials) || ~isnumeric(cfg.n_trials) || cfg.n_trials < 1
        error('cfg.n_trials must be a positive scalar.');
    end

    if ~isscalar(cfg.time_pause) || ~isnumeric(cfg.time_pause) || cfg.time_pause < 0
        error('cfg.time_pause must be a non-negative scalar.');
    end

    if cfg.stimbox.enable
        if ~ischar(cfg.stimbox.com) || isempty(cfg.stimbox.com)
            error('cfg.stimbox.com must be a non-empty char array.');
        end
        if ~isscalar(cfg.stimbox.baud) || ~isnumeric(cfg.stimbox.baud) || cfg.stimbox.baud <= 0
            error('cfg.stimbox.baud must be a positive scalar.');
        end
    end

    if cfg.pulsepal.enable
        if ~ischar(cfg.pulsepal.com) || isempty(cfg.pulsepal.com)
            error('cfg.pulsepal.com must be a non-empty char array.');
        end

        if ~isscalar(cfg.pulsepal.channel) || cfg.pulsepal.channel < 1 || cfg.pulsepal.channel > 4
            error('cfg.pulsepal.channel must be 1..4.');
        end

        if cfg.pulsepal.phase1_voltage < -10 || cfg.pulsepal.phase1_voltage > 10
            error('PulsePal phase1 voltage must be between -10 and 10 V.');
        end
        if cfg.pulsepal.phase2_voltage < -10 || cfg.pulsepal.phase2_voltage > 10
            error('PulsePal phase2 voltage must be between -10 and 10 V.');
        end
        if cfg.pulsepal.resting_voltage < -10 || cfg.pulsepal.resting_voltage > 10
            error('PulsePal resting voltage must be between -10 and 10 V.');
        end

        if cfg.pulsepal.phase1_duration_s < 0.0001
            error('PulsePal phase1 duration must be >= 0.0001 s.');
        end
        if cfg.pulsepal.interphase_interval_s < 0.0001
            error('PulsePal interphase interval must be >= 0.0001 s.');
        end
        if cfg.pulsepal.phase2_duration_s < 0.0001
            error('PulsePal phase2 duration must be >= 0.0001 s.');
        end
        if cfg.pulsepal.interpulse_interval_s < 0.0001
            error('PulsePal inter-pulse interval must be >= 0.0001 s.');
        end
        if cfg.pulsepal.burst_duration_s < 0
            error('PulsePal burst duration must be >= 0.');
        end
        if cfg.pulsepal.interburst_interval_s < 0
            error('PulsePal inter-burst interval must be >= 0.');
        end
        if cfg.pulsepal.train_delay_s < 0
            error('PulsePal train delay must be >= 0.');
        end
        if cfg.pulsepal.train_duration_s < 0.0001
            error('PulsePal train duration must be >= 0.0001 s.');
        end
    end

    if cfg.motor.enable
        if ~ischar(cfg.motor.com) || isempty(cfg.motor.com)
            error('cfg.motor.com must be a non-empty char array.');
        end

        if ~ischar(cfg.motor.mode) || isempty(cfg.motor.mode)
            error('cfg.motor.mode must be ''single'' or ''stepped''.');
        end

        if ~strcmpi(cfg.motor.mode, 'single') && ~strcmpi(cfg.motor.mode, 'stepped')
            error('cfg.motor.mode must be ''single'' or ''stepped''.');
        end

        if ~isscalar(cfg.motor.settle_pause_s) || ~isnumeric(cfg.motor.settle_pause_s) || cfg.motor.settle_pause_s < 0
            error('cfg.motor.settle_pause_s must be >= 0.');
        end

        if strcmpi(cfg.motor.mode, 'stepped')
            if ~isscalar(cfg.motor.step_mm) || ~isnumeric(cfg.motor.step_mm) || cfg.motor.step_mm <= 0
                error('cfg.motor.step_mm must be > 0 for stepped motor mode.');
            end

            if ~isscalar(cfg.motor.frames_per_position) || ~isnumeric(cfg.motor.frames_per_position) || cfg.motor.frames_per_position < 1
                error('cfg.motor.frames_per_position must be >= 1 for stepped motor mode.');
            end
        end
    end
end

% =========================================================================
% Explicit frame set builders
% =========================================================================
function framesOut = localBuildStimBoxFrameSets(stimboxCfg, nFrames)
    framesOut = struct();
    framesOut.d3_frames = [];
    framesOut.d5_frames = [];
    framesOut.d6_frames = [];

    if ~stimboxCfg.enable
        return;
    end

    sharedStart  = localGetNumericField(stimboxCfg, {'start_frame','frame_start'}, NaN);
    sharedRepeat = localGetLogicalField(stimboxCfg, {'repeat_enable','repeat'}, false);
    sharedEvery  = localGetNumericField(stimboxCfg, {'repeat_interval_frames','repeat_every_frames','repeat_after_frames'}, NaN);

    % IMPORTANT:
    % Use START FRAMES only, not full duration windows.
    % This matches the older working behavior much better.
    triggerFrames = localBuildStimBoxTriggerFrames(sharedStart, sharedRepeat, sharedEvery, nFrames);

    framesOut.d3_frames = localResolveStimLineFrames(stimboxCfg, 'd3', triggerFrames, nFrames);
    framesOut.d5_frames = localResolveStimLineFrames(stimboxCfg, 'd5', triggerFrames, nFrames);
    framesOut.d6_frames = localResolveStimLineFrames(stimboxCfg, 'd6', triggerFrames, nFrames);
end

function frames = localBuildStimBoxTriggerFrames(startFrame, repeatOn, repeatEvery, nFrames)
    frames = [];

    if isempty(startFrame) || ~isnumeric(startFrame) || isnan(startFrame)
        return;
    end

    startFrame = round(startFrame);
    if startFrame < 1 || startFrame > nFrames
        return;
    end

    if ~repeatOn || isempty(repeatEvery) || ~isnumeric(repeatEvery) || isnan(repeatEvery) || repeatEvery < 1
        frames = startFrame;
    else
        repeatEvery = max(1, round(repeatEvery));
        frames = startFrame:repeatEvery:nFrames;
    end

    frames = localCleanFrameVector(frames, nFrames);
end

function frames = localResolveStimLineFrames(stimboxCfg, lineName, triggerFrames, nFrames)

    frames = [];

    explicitField = [lineName '_frames'];
    enableField   = [lineName '_enable'];
    legacyField   = [lineName '_trig'];

    if isfield(stimboxCfg, explicitField)
        frames = localCleanFrameVector(stimboxCfg.(explicitField), nFrames);
        return;
    end

    lineEnabled = localGetLogicalField(stimboxCfg, {enableField}, false);

    if lineEnabled
        frames = triggerFrames;
        return;
    end

    if isfield(stimboxCfg, legacyField)
        legacyVal = stimboxCfg.(legacyField);
        if isnumeric(legacyVal) && ~isempty(legacyVal) && ~isnan(legacyVal)
            if isscalar(legacyVal) && legacyVal == -1
                frames = 1:nFrames;
            else
                frames = localCleanFrameVector(legacyVal, nFrames);
            end
        end
    end
end

function frames = localBuildPulsePalTriggerFrames(pulsepalCfg, nFrames)
    frames = [];

    if ~pulsepalCfg.enable
        return;
    end

    if isfield(pulsepalCfg, 'trigger_frames')
        frames = localCleanFrameVector(pulsepalCfg.trigger_frames, nFrames);
        return;
    end

    startFrame  = localGetNumericField(pulsepalCfg, {'start_frame','frame_start'}, NaN);
    repeatOn    = localGetLogicalField(pulsepalCfg, {'repeat_enable','repeat'}, false);
    repeatEvery = localGetNumericField(pulsepalCfg, {'repeat_interval_frames','repeat_every_frames','repeat_after_frames'}, NaN);

    if isempty(startFrame) || isnan(startFrame)
        return;
    end

    startFrame = round(startFrame);
    if startFrame < 1 || startFrame > nFrames
        return;
    end

    if ~repeatOn || isempty(repeatEvery) || isnan(repeatEvery) || repeatEvery < 1
        frames = startFrame;
    else
        repeatEvery = max(1, round(repeatEvery));
        frames = startFrame:repeatEvery:nFrames;
    end

    frames = localCleanFrameVector(frames, nFrames);
end

% =========================================================================
% Motor
% =========================================================================
function [connection, axis, homeMM] = localOpenMotor(comName)
    % IMPORTANT: no "import zaber.motion..." here.
    %
    % MATLAB resolves import statements when the FILE IS PARSED, not when
    % the function runs. A static import therefore makes the whole file
    % fail to load on any machine without the Zaber Motion toolbox, even
    % if the motor is never used, and a try/catch around it does not help.
    %
    % Fully qualified names are resolved at call time instead, so this
    % file always loads and only errors if the motor is actually opened.

    if ~localIsZaberAvailable()
        error(['Zaber Motion toolbox not found, so the motor cannot be opened.' sprintf('\n') ...
               'Install the Zaber Motion Library for MATLAB, or disable the motor in the GUI.']);
    end

    connection = zaber.motion.ascii.Connection.openSerialPort(comName);
    deviceList = connection.detectDevices();

    if isempty(deviceList)
        error('No Zaber devices detected on %s.', comName);
    end

    device = deviceList(1);
    axis = device.getAxis(1);
    homeMM = axis.getPosition(zaber.motion.Units.LENGTH_MILLIMETRES);
end

function tf = localIsZaberAvailable()
    % Runtime check for the Zaber Motion toolbox.
    % Kept separate so every motor entry point can guard itself cheaply.

    persistent cachedTF

    if ~isempty(cachedTF)
        tf = cachedTF;
        return;
    end

    tf = false;

    try
        if exist('zaber.motion.Units', 'class') == 8
            tf = true;
        end
    catch
    end

    if ~tf
        try
            % Touching the class is the most reliable probe across versions.
            zaber.motion.Units.LENGTH_MILLIMETRES;
            tf = true;
        catch
            tf = false;
        end
    end

    cachedTF = tf;
end

function positionsAbsMM = localBuildMotorPositions(homeMM, motorCfg)
    if ~motorCfg.enable
        positionsAbsMM = NaN;
        return;
    end

    useAbsolute = ~isempty(motorCfg.start_mm) && isnumeric(motorCfg.start_mm) && ~isnan(motorCfg.start_mm);

    if useAbsolute
        startAbs = motorCfg.start_mm;

        if strcmpi(motorCfg.mode, 'single')
            positionsAbsMM = startAbs;
            return;
        end

        if ~isempty(motorCfg.end_mm) && isnumeric(motorCfg.end_mm) && ~isnan(motorCfg.end_mm)
            endAbs = motorCfg.end_mm;
        else
            endAbs = startAbs;
        end
    else
        startAbs = homeMM + motorCfg.start_offset_mm;

        if strcmpi(motorCfg.mode, 'single')
            positionsAbsMM = startAbs;
            return;
        end

        endAbs = homeMM + motorCfg.end_offset_mm;
    end

    stepMM = abs(motorCfg.step_mm);

    if abs(endAbs - startAbs) < eps
        positionsAbsMM = startAbs;
        return;
    end

    if endAbs < startAbs
        stepMM = -stepMM;
    end

    positionsAbsMM = startAbs:stepMM:endAbs;

    if isempty(positionsAbsMM)
        positionsAbsMM = [startAbs endAbs];
    else
        if abs(positionsAbsMM(end) - endAbs) > 1e-12
            positionsAbsMM = [positionsAbsMM endAbs];
        end
    end
end

function plan = localBuildMotorPlan(motorCfg, positionsAbsMM, nFrames)
    plan = struct();
    plan.frames = [];
    plan.targets_abs_mm = [];

    if ~motorCfg.enable
        return;
    end

    if isempty(positionsAbsMM) || all(isnan(positionsAbsMM))
        return;
    end

    cycleStart = localGetNumericField(motorCfg, {'frame_start','start_frame'}, 1);
    cycleDur   = localGetNumericField(motorCfg, {'frame_duration','duration_frames'}, nFrames);
    repeatOn   = localGetLogicalField(motorCfg, {'repeat_enable','repeat'}, false);
    repeatEvery = localGetNumericField(motorCfg, {'repeat_interval_frames','repeat_every_frames','repeat_after_frames'}, NaN);

    cycleStart = max(1, round(cycleStart));
    cycleDur   = max(1, round(cycleDur));

    if ~repeatOn || isempty(repeatEvery) || isnan(repeatEvery) || repeatEvery < 1
        cycleStarts = cycleStart;
    else
        repeatEvery = max(1, round(repeatEvery));
        cycleStarts = cycleStart:repeatEvery:nFrames;
    end

    nPos = numel(positionsAbsMM);

    for iC = 1:numel(cycleStarts)
        c0 = cycleStarts(iC);
        c1 = min(nFrames, c0 + cycleDur - 1);

        if strcmpi(motorCfg.mode, 'single')
            if c0 >= 1 && c0 <= nFrames
                plan.frames(end+1) = c0; %#ok<AGROW>
                plan.targets_abs_mm(end+1) = positionsAbsMM(1); %#ok<AGROW>
            end
            continue;
        end

        framesPer = max(1, round(motorCfg.frames_per_position));
        slotFrames = c0:framesPer:c1;

        if isempty(slotFrames)
            slotFrames = c0;
        end

        if motorCfg.periodic
            for k = 1:numel(slotFrames)
                idx = mod(k-1, nPos) + 1;
                plan.frames(end+1) = slotFrames(k); %#ok<AGROW>
                plan.targets_abs_mm(end+1) = positionsAbsMM(idx); %#ok<AGROW>
            end
        else
            nUse = min(numel(slotFrames), nPos);
            for k = 1:nUse
                plan.frames(end+1) = slotFrames(k); %#ok<AGROW>
                plan.targets_abs_mm(end+1) = positionsAbsMM(k); %#ok<AGROW>
            end
        end
    end

    [plan.frames, sortIdx] = sort(plan.frames);
    if ~isempty(sortIdx)
        plan.targets_abs_mm = plan.targets_abs_mm(sortIdx);
    end
end

function [actualPosMM, ok] = localMoveMotorBeforeStableScan(cfg, motorAxis, targetAbsMM, iMotor, nMotor)
    actualPosMM = NaN;
    ok = false;

    if isempty(motorAxis)
        error('Motor is enabled, but motorAxis is empty.');
    end

    if isempty(targetAbsMM) || ~isnumeric(targetAbsMM) || isnan(targetAbsMM)
        error('Invalid motor target position.');
    end

    localGuiLog(cfg, sprintf( ...
        'Motor move BEFORE acquisition: %d/%d -> abs %.3f mm', ...
        iMotor, nMotor, targetAbsMM));

    motorAxis.moveAbsolute(targetAbsMM, zaber.motion.Units.LENGTH_MILLIMETRES);

    if isfield(cfg, 'motor') && isfield(cfg.motor, 'settle_pause_s') && ...
            isnumeric(cfg.motor.settle_pause_s) && cfg.motor.settle_pause_s > 0

        localGuiLog(cfg, sprintf('Motor settling pause: %.3f s', cfg.motor.settle_pause_s));
        pause(cfg.motor.settle_pause_s);
    end

    try
        actualPosMM = motorAxis.getPosition(zaber.motion.Units.LENGTH_MILLIMETRES);
    catch
        actualPosMM = targetAbsMM;
    end

    localGuiLog(cfg, sprintf( ...
        'Motor stable BEFORE acquisition: requested %.3f mm | actual %.3f mm', ...
        targetAbsMM, actualPosMM));

    ok = true;
end

% =========================================================================
% Fast slice pipeline: non-blocking motor move + deferred wait
% =========================================================================
function ok = localStartMotorMoveAsync(cfg, motorAxis, targetAbsMM) %#ok<INUSL>
    % Issue a move WITHOUT waiting for it to finish, so the caller can do
    % useful work (saving the previous MAT file) while the stage travels.

    ok = false;

    if isempty(motorAxis)
        return;
    end

    if isempty(targetAbsMM) || ~isnumeric(targetAbsMM) || isnan(targetAbsMM)
        return;
    end

    try
        % Zaber Motion: moveAbsolute(position, unit, waitUntilIdle)
        motorAxis.moveAbsolute(targetAbsMM, ...
            zaber.motion.Units.LENGTH_MILLIMETRES, false);
        ok = true;

    catch
        % Older Zaber Motion builds reject the third argument.
        % Nothing is issued here; the caller falls back to a blocking move.
        ok = false;
    end
end

function actualPosMM = localFinishMotorMove(cfg, motorAxis, targetAbsMM)
    % Block until a previously issued asynchronous move has completed,
    % apply the settle pause, then read back the position.

    actualPosMM = targetAbsMM;

    try
        motorAxis.waitUntilIdle();
    catch
        % If waitUntilIdle is unavailable, the settle pause below is the
        % only guard. Keep it conservative in that case.
    end

    try
        if isfield(cfg, 'motor') && isfield(cfg.motor, 'settle_pause_s') && ...
                isnumeric(cfg.motor.settle_pause_s) && cfg.motor.settle_pause_s > 0
            pause(cfg.motor.settle_pause_s);
        end
    catch
    end

    try
        actualPosMM = motorAxis.getPosition(zaber.motion.Units.LENGTH_MILLIMETRES);
    catch
        actualPosMM = targetAbsMM;
    end
end

% =========================================================================
% StimBox serial open
% =========================================================================
function port = localOpenStimBoxPort(comName, baudRate)
    port = [];

    hasSerialPort = (exist('serialport', 'file') == 2) || (exist('serialport', 'class') == 8);

    if hasSerialPort
        port = serialport(comName, baudRate);
        try
            flush(port);
        catch
        end
    else
        try
            oldObj = instrfind('Port', comName);
            if ~isempty(oldObj)
                fclose(oldObj);
                delete(oldObj);
            end
        catch
        end

        port = serial(comName);
        port.BaudRate = baudRate;
        fopen(port);
    end
end

% =========================================================================
% Save names and journal text
% =========================================================================
function [nameFile, nameShort] = localMakeSaveName(FS, cfg, sessionTag, motorPositionsAbsMM, motorHomeMM, iTrial) %#ok<INUSD>
    % sessionTag is used as the cache key for the scan index counter.
    % Save path:
    %   Data\<save_owner>\<xp_name>\<xp_name>_scanN[_StimBox][_ElectricalStim][_Motor].mat
    %
    % IMPORTANT:
    % scan number is global within the experiment folder, independent of suffix.

if ~isfield(cfg, 'save_owner') || isempty(cfg.save_owner)
    cfg.save_owner = 'Soner';
end

% Default experiment folder
% HUMOR_OUTPUT_ROOT_CDATA_V1
if isfield(cfg, 'output_root') && ~isempty(cfg.output_root)
    outputRoot = cfg.output_root;
else
    outputRoot = 'C:\Data';
end
baseFolder = fullfile(outputRoot, cfg.save_owner, cfg.xp_name);

if isfield(cfg, 'output_base_folder') && ~isempty(cfg.output_base_folder)
    baseFolder = cfg.output_base_folder;
end

if ~exist(baseFolder, 'dir')
    mkdir(baseFolder);
end

% In split motor mode, save inside the prepared session subfolder.
saveFolder = baseFolder;

useSplitMotorFolder = false;
try
    useSplitMotorFolder = ...
        isfield(cfg, 'motor') && isstruct(cfg.motor) && ...
        isfield(cfg.motor, 'enable') && logical(cfg.motor.enable) && ...
        isfield(cfg.motor, 'acquisition_mode') && ...
        strcmpi(cfg.motor.acquisition_mode, 'split') && ...
        isfield(cfg, 'output_session_folder') && ...
        ~isempty(cfg.output_session_folder);
catch
    useSplitMotorFolder = false;
end

if useSplitMotorFolder
    saveFolder = cfg.output_session_folder;
end

if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end

deviceSuffix = localBuildDeviceSuffix(cfg);

% V5 anatomy numbering. Anatomy is saved only after the user confirms it.
% Use simple persistent names that are easy to identify in deConfUSIon:
%   low_res_anatomy_1.mat, low_res_anatomy_2.mat, ...
%   high_res_anatomy_1.mat, high_res_anatomy_2.mat, ...
% 2D/3D is stored in metadata rather than cluttering the filename.
imagingMode = localGetImagingMode(cfg);

if localIsLowResAnatomyPreset(cfg)
    anatomyIdx = localGetNextAnatomyIndex(saveFolder, 'low_res_anatomy');
    nameShort = sprintf('low_res_anatomy_%d.mat', anatomyIdx);
elseif strcmpi(imagingMode, 'highres2d') || strcmpi(imagingMode, 'highres3d')
    anatomyIdx = localGetNextAnatomyIndex(saveFolder, 'high_res_anatomy');
    nameShort = sprintf('high_res_anatomy_%d.mat', anatomyIdx);
else
    % Scan index is counted inside the folder where files are saved.
    scanIdx = localGetNextScanIndex(saveFolder, cfg.xp_name, sessionTag);
    if isempty(deviceSuffix)
        nameShort = sprintf('%s_scan%d.mat', cfg.xp_name, scanIdx);
    else
        nameShort = sprintf('%s_scan%d%s.mat', cfg.xp_name, scanIdx, deviceSuffix);
    end
end

nameFile = fullfile(saveFolder, nameShort);
end
function idx = localGetNextAnatomyIndex(folderPath, prefix)
    idx = 1;
    try
        d = dir(fullfile(folderPath, [prefix '_*.mat']));
        nums = [];
        expr = ['^' regexptranslate('escape',prefix) '_(\d+)\.mat$'];
        for ii = 1:numel(d)
            tok = regexp(d(ii).name, expr, 'tokens', 'once');
            if ~isempty(tok)
                n = str2double(tok{1});
                if isfinite(n), nums(end+1) = n; end %#ok<AGROW>
            end
        end
        if ~isempty(nums), idx = max(nums)+1; end
    catch
        idx = 1;
    end
end

function tf = localAskSaveAnatomy(cfg, imagingMode)
    tf = false;
    if nargin < 2, imagingMode = 'anatomy'; end
    if strcmpi(imagingMode,'doppler')
        kind = 'low-resolution Doppler anatomy';
    elseif strcmpi(imagingMode,'highres3d')
        kind = 'high-resolution 3D anatomy';
    elseif strcmpi(imagingMode,'highres2d')
        kind = 'high-resolution 2D anatomy';
    else
        kind = 'anatomy';
    end

    localGuiStatus(cfg, ['Review ' kind ' - save?'], 'notready');
    localGuiLog(cfg, ['Anatomy displayed. Waiting for Yes/No save decision: ' kind '.']);

    answer = '';
    try
        answer = questdlg(sprintf('Save this %s?', kind), ...
            'Save anatomy?', 'Yes', 'No', 'Yes');
    catch
        % Desktop-less fallback. Default to NO rather than saving unwanted data.
        answer = 'No';
    end
    tf = strcmpi(answer,'Yes');
    if tf
        localGuiLog(cfg,'Save anatomy: YES.');
    else
        localGuiLog(cfg,'Save anatomy: NO.');
    end
end

function [nameFileOut, nameShortOut] = localMakeFileNameUnique(nameFileIn)
    [folderPath, baseName, ext] = fileparts(nameFileIn);

    nameFileOut = nameFileIn;
    nameShortOut = [baseName ext];

    if ~exist(nameFileOut, 'file')
        return;
    end

    for k = 1:999
        candidateShort = sprintf('%s_dup%03d%s', baseName, k, ext);
        candidateFull = fullfile(folderPath, candidateShort);

        if ~exist(candidateFull, 'file')
            nameFileOut = candidateFull;
            nameShortOut = candidateShort;
            return;
        end
    end

    error('Could not create unique filename for %s.', nameFileIn);
end


function localSaveAcqInfo(nameFile, md, cfg)
    % -------------------------------------------------------------------
    % The data file holds only I, metadata and events, matching the
    % scanner GUI exactly. A loader that scans variables would otherwise
    % pick md over metadata and misread the geometry.
    %
    % The acquisition bookkeeping in md (timing QC, motor state, probe
    % type, trigger schedule) is still worth keeping, so it is written
    % beside the data file as <name>_acqinfo.mat.
    %
    % A failure here must never lose the scan, so it only warns.
    % -------------------------------------------------------------------

    try
        [folderPath, baseName, ~] = fileparts(nameFile);
        acqFile = fullfile(folderPath, [baseName '_acqinfo.mat']);

        save(acqFile, 'md', '-v7');

    catch MEacq
        localGuiLog(cfg, sprintf( ...
            'WARNING: could not write acquisition info sidecar: %s', MEacq.message));
    end
end

function [metadataOut, eventsOut] = localBuildCompanyVars(md)
    % -------------------------------------------------------------------
    % SAVE-FORMAT COMPATIBILITY
    %
    % The scanner GUI saves three variables:
    %       I, metadata, events
    % where "metadata" holds ONLY the scanner's own fields
    % (imageDim, imageSize, imageType, origen, t0, tag, time, voxelSize).
    %
    % This script previously saved I and md, where md was the scanner
    % metadata with ~40 extra acquisition fields merged in. Any loader
    % looking for a variable called "metadata" found nothing and fell
    % back to guessing the geometry, which is why a [80 64 54 90] volume
    % displayed as 64 slices instead of 54.
    %
    % Here md is split back apart:
    %   metadata -> scanner-native fields only, byte-compatible with the
    %               GUI format
    %   events   -> taken from the scanner tag field, or an empty struct
    %               matching what the GUI writes
    %
    % The full md is still saved alongside, so nothing is lost.
    % -------------------------------------------------------------------

    % Fields this toolbox adds. Everything else is treated as scanner-native,
    % so a future scanner field is preserved automatically.
    dropExact = { ...
        'acquisition_mode', 'imaging_mode', 'probe_type', 'tr_unit_s', 'nblocksImage', ...
        'data_size', 'data_ndims', 'is_volumetric', ...
        'timeIndex', 'sliceIndex', 'image_role', 'is_anatomy'};

    dropPrefix = {'geom_', 'motor_', 'acq_', 'actual_', 'requested_', 'metadata_', 'highres_', 'anatomy_', 'vendor_'};

    metadataOut = struct();

    if ~isstruct(md) || numel(md) ~= 1
        eventsOut = localEmptyEvents();
        return;
    end

    fn = fieldnames(md);

    for i = 1:numel(fn)
        thisName = fn{i};

        if any(strcmp(thisName, dropExact))
            continue;
        end

        skipThis = false;
        for k = 1:numel(dropPrefix)
            if strncmp(thisName, dropPrefix{k}, numel(dropPrefix{k}))
                skipThis = true;
                break;
            end
        end

        if skipThis
            continue;
        end

        metadataOut.(thisName) = md.(thisName);
    end

    % The scanner stores event marks in the tag field, and the GUI writes
    % the same structure out as a separate "events" variable.
    if isfield(md, 'tag')
        eventsOut = md.tag;
    else
        eventsOut = localEmptyEvents();
    end
end

function e = localEmptyEvents()
    % Matches the GUI format exactly: image is an empty double, text an
    % empty cell.
    e = struct();
    e.image = [];
    e.text = {};
end

function localReliableSaveMat(nameFile, I, md, cfg)

    % Rebuild the scanner-native variables so the file matches the GUI format.
    [metadata, events] = localBuildCompanyVars(md);

    [saveFolder, saveBase, saveExt] = fileparts(nameFile);

    if ~exist(saveFolder, 'dir')
        mkdir(saveFolder);
    end

    lastErr = '';

    for attempt = 1:3

        tmpFile = fullfile(saveFolder, sprintf('%s__tmp_%s_%06d%s', ...
            saveBase, datestr(now, 'HHMMSS'), round(rand * 1e6), saveExt));

        try
            if exist(tmpFile, 'file')
                delete(tmpFile);
            end

            save(tmpFile, 'I', 'metadata', 'events', '-v7.3');

            if ~exist(tmpFile, 'file')
                error('Temporary MAT file was not created.');
            end

            d = dir(tmpFile);
            if isempty(d) || d.bytes <= 0
                error('Temporary MAT file is empty.');
            end

            varsInTmp = whos('-file', tmpFile);
            varNames = {varsInTmp.name};

            if ~ismember('I', varNames)
                error('Temporary MAT file created, but variable I is missing.');
            end

            % The loader reads "metadata" and "events".
            if ~ismember('metadata', varNames)
                error('Temporary MAT file created, but variable metadata is missing.');
            end

            if ~ismember('events', varNames)
                error('Temporary MAT file created, but variable events is missing.');
            end

            % md must NOT be here: a loader that scans variables picks md
            % over metadata and misreads the geometry.
            if ismember('md', varNames)
                error('Temporary MAT file still contains md.');
            end

            [ok, msg] = movefile(tmpFile, nameFile, 'f');
            if ~ok
                error('Could not move temporary MAT file into final location: %s', msg);
            end

            if ~exist(nameFile, 'file')
                error('Final MAT file missing after movefile.');
            end

            varsFinal = whos('-file', nameFile);
            finalNames = {varsFinal.name};

            if ~ismember('I', finalNames) || ~ismember('metadata', finalNames) || ~ismember('events', finalNames)
                error('Final MAT file verification failed: I, metadata or events missing.');
            end

            localSaveAcqInfo(nameFile, md, cfg);

            localGuiLog(cfg, sprintf('Reliable save verified: %s', nameFile));
            return;

        catch ME
            lastErr = ME.message;

            try
                if exist(tmpFile, 'file')
                    delete(tmpFile);
                end
            catch
            end

            localGuiLog(cfg, sprintf('Save attempt %d failed: %s', attempt, lastErr));
            pause(0.5);
        end
    end

    error('Reliable save failed after 3 attempts: %s', lastErr);
end

function localFastSaveMat(nameFile, I, md, cfg)

    % Rebuild the scanner-native variables so the file matches the GUI format.
    [metadata, events] = localBuildCompanyVars(md);
    % Fast save for split-motor slice files.
    % Uses -v7 first because it is much faster than -v7.3 for small files.
    % Falls back to -v7.3 if needed.
    %
    % 3D PROBE NOTE:
    % -v7 cannot store a variable larger than 2 GB. Volumetric slice files
    % can exceed that. Rather than failing and retrying (which costs a full
    % wasted write), the size is checked up front and -v7.3 is used
    % directly for large arrays.

    [saveFolder, ~, ~] = fileparts(nameFile);

    if ~exist(saveFolder, 'dir')
        mkdir(saveFolder);
    end

    useV73Directly = false;

    try
        infoI = whos('I');
        % Stay well under the 2 GB limit.
        if ~isempty(infoI) && infoI.bytes > 1.5e9
            useV73Directly = true;
        end
    catch
    end

    if useV73Directly
        try
            localGuiLog(cfg, 'Large volume detected: saving with -v7.3.');
            save(nameFile, 'I', 'metadata', 'events', '-v7.3');
            localSaveAcqInfo(nameFile, md, cfg);
            return;
        catch MEbig
            localGuiLog(cfg, sprintf('Large -v7.3 save failed, using reliable save: %s', MEbig.message));
            localReliableSaveMat(nameFile, I, md, cfg);
            return;
        end
    end

    try
        save(nameFile, 'I', 'metadata', 'events', '-v7');
        localSaveAcqInfo(nameFile, md, cfg);
        return;
    catch ME1
        try
            localGuiLog(cfg, sprintf('Fast -v7 save failed, trying -v7.3: %s', ME1.message));
            save(nameFile, 'I', 'metadata', 'events', '-v7.3');
            localSaveAcqInfo(nameFile, md, cfg);
        catch ME2
            localGuiLog(cfg, sprintf('Fast save failed, using reliable save: %s', ME2.message));
            localReliableSaveMat(nameFile, I, md, cfg);
        end
    end
end

function [nameFileOut, nameShortOut] = localAppendMotorPositionToSaveName(nameFileIn, cfg, absPosMM, homeMM, iMotor, iTimeIndex)

    if nargin < 6 || isempty(iTimeIndex) || isnan(iTimeIndex)
        iTimeIndex = 1;
    end

    [folderPath, baseName, ext] = fileparts(nameFileIn);

    motorMode = localGetMotorAcqMode(cfg);

    switch lower(motorMode)

        case 'split'
            % IMPORTANT for motor.m:
            % It can parse:
            %   slice001_t001
            %   slice002_t001
            %   slice001_t002
            %
            % Keep this simple and analysis-friendly.
            tag = sprintf('M_split_slice%03d_t%03d', ...
                round(iMotor), round(iTimeIndex));

        case 'continuous'
            % One long MAT file containing all motor positions.
            tag = 'M_continuousmotor';

        otherwise
            tag = 'M_motor';
    end

    nameShortOut = [baseName '_' tag ext];
    nameFileOut = fullfile(folderPath, nameShortOut);
end
function [nameFileOut, nameShortOut] = localAppendSplitSliceToSaveName(nameFileIn, iTrial, iSlice, nSlices, absPosMM, homeMM) %#ok<INUSD>
    [folderPath, baseName, ext] = fileparts(nameFileIn);

    nameShortOut = sprintf('%s_T%03d_Slice%03dof%03d%s', ...
        baseName, round(iTrial), round(iSlice), round(nSlices), ext);

    nameFileOut = fullfile(folderPath, nameShortOut);
end

function md = localAddMotorMetadata(md, cfg, motorHomeMM, requestedMotorAbsMM, actualMotorAbsMM, ...
    iMotor, nMotor, iTimeIndex, nTimeTotal, globalFrameStart, globalFrameEnd, ...
    continuousMotorPlan)

    if nargin < 12
        continuousMotorPlan = struct('frames', [], 'targets_abs_mm', []);
    end

    if ~isstruct(md)
        tmp = md;
        md = struct();
        md.original_md = tmp;
    end

    motorMode = localGetMotorAcqMode(cfg);

    try
        md.motor_enabled = logical(cfg.motor.enable);
        md.motor_acquisition_mode = motorMode;
        md.motor_moves_during_acquisition = strcmpi(motorMode, 'continuous');
        md.motor_stable_acquisition = strcmpi(motorMode, 'split');

        md.sliceIndex = iMotor;
        md.timeIndex = iTimeIndex;
        md.globalFrameStart = globalFrameStart;
        md.globalFrameEnd = globalFrameEnd;

        md.motor_index = iMotor;
        md.motor_n_positions = nMotor;
        md.motor_time_index = iTimeIndex;
        md.motor_n_time_indices = nTimeTotal;

        md.motor_requested_abs_mm = requestedMotorAbsMM;
        md.motor_actual_abs_mm = actualMotorAbsMM;
        md.motor_home_abs_mm = motorHomeMM;
        md.motor_requested_rel_mm = requestedMotorAbsMM - motorHomeMM;
        md.motor_actual_rel_mm = actualMotorAbsMM - motorHomeMM;
        md.motor_settle_pause_s = cfg.motor.settle_pause_s;

        md.motor_frames_per_slice = cfg.motor.frames_per_position;
        md.motor_total_target_frames = cfg.n_frames;

        motorMeta = struct();
        motorMeta.acquisitionMode = motorMode;
        motorMeta.sliceIndex = iMotor;
        motorMeta.timeIndex = iTimeIndex;
        motorMeta.globalFrameStart = globalFrameStart;
        motorMeta.globalFrameEnd = globalFrameEnd;
        motorMeta.nMotorPositions = nMotor;
        motorMeta.nTimeIndices = nTimeTotal;
        motorMeta.framesPerSlice = cfg.motor.frames_per_position;
        motorMeta.totalTargetFrames = cfg.n_frames;
        motorMeta.requestedAbsMM = requestedMotorAbsMM;
        motorMeta.actualAbsMM = actualMotorAbsMM;
        motorMeta.homeAbsMM = motorHomeMM;
        motorMeta.movesDuringAcquisition = strcmpi(motorMode, 'continuous');
        motorMeta.stableDuringAcquisition = strcmpi(motorMode, 'split');

        if strcmpi(motorMode, 'continuous')
            motorMeta.continuousMoveFrames = continuousMotorPlan.frames;
            motorMeta.continuousMoveTargetsAbsMM = continuousMotorPlan.targets_abs_mm;
            motorMeta.reconstructionHint = ...
                'Continuous mode: use one long I movie with motorFramesPerSlice from metadata.';
        else
            motorMeta.reconstructionHint = ...
                'Split mode: group files by sliceIndex and timeIndex or by slice###_t### filename.';
        end

        md.motorMeta = motorMeta;
    catch
    end
end

function [nameFileOut, nameShortOut] = localAppendContinuousMotorToSaveName(nameFileIn, nSlices, framesPerSlice, startAbsMM, endAbsMM, homeMM) %#ok<INUSD>
    [folderPath, baseName, ext] = fileparts(nameFileIn);

    nameShortOut = sprintf('%s_ContinuousMotor_Slices%03d%s', ...
        baseName, round(nSlices), ext);

    nameFileOut = fullfile(folderPath, nameShortOut);
end

function suffix = localBuildDeviceSuffix(cfg)
    parts = {};

    imagingMode = localGetImagingMode(cfg);
    if strcmpi(imagingMode, 'highres2d')
        parts{end+1} = 'anatomy_HR2D'; %#ok<AGROW>
    elseif strcmpi(imagingMode, 'highres3d')
        parts{end+1} = 'anatomy_HR3D'; %#ok<AGROW>
    end

    if isfield(cfg, 'stimbox') && isstruct(cfg.stimbox) && isfield(cfg.stimbox, 'enable') && logical(cfg.stimbox.enable)
        parts{end+1} = 'SB'; %#ok<AGROW>
    end

    if isfield(cfg, 'pulsepal') && isstruct(cfg.pulsepal) && isfield(cfg.pulsepal, 'enable') && logical(cfg.pulsepal.enable)
        parts{end+1} = 'ES'; %#ok<AGROW>
    end

% Do not add generic _M here.
% Motor mode is added later as:
%   M_continuousmotor
%   M_split_slice001_t001

    if isempty(parts)
        suffix = '';
    else
        suffix = ['_' strjoin(parts, '_')];
    end
end

function scanIdx = localGetNextScanIndex(folderPath, expName, sessionKey)
    % IMPORTANT:
    % Use one common scan counter across ALL scan files in this experiment folder,
    % regardless of device suffix such as _Motor, _StimBox, _SB_M, etc.
    %
    % SPEED NOTE (split motor mode):
    % Scanning the folder with dir() before every slice file gets slower as
    % the session grows, which shows up as dead time between slices. The
    % index is therefore resolved from disk once per run and then simply
    % incremented in memory. sessionKey changes every run, so a new run
    % always re-reads the folder. Collisions remain impossible because
    % localMakeFileNameUnique still checks the final path.

    persistent cachedKey cachedIdx

    if nargin < 3 || isempty(sessionKey)
        sessionKey = '';
    end

    thisKey = [sessionKey '|' folderPath '|' expName];

    if ~isempty(cachedKey) && ~isempty(cachedIdx) && strcmp(cachedKey, thisKey)
        cachedIdx = cachedIdx + 1;
        scanIdx = cachedIdx;
        return;
    end

    d = dir(fullfile(folderPath, [expName '_scan*.mat']));
    scanNums = [];

    expr = ['^' regexptranslate('escape', expName) '_scan(\d+)(?:_.*)?\.mat$'];

    for i = 1:numel(d)
        thisName = d(i).name;
        tok = regexp(thisName, expr, 'tokens', 'once');

        if ~isempty(tok)
            n = str2double(tok{1});
            if ~isnan(n)
                scanNums(end+1) = n; %#ok<AGROW>
            end
        end
    end

    if isempty(scanNums)
        scanIdx = 1;
    else
        scanIdx = max(scanNums) + 1;
    end

    cachedKey = thisKey;
    cachedIdx = scanIdx;
end

function txt = localMakeJournalText(nameShort, cfg, motorPositionsAbsMM, motorHomeMM, iTrial)
    motorTag = localMotorTag(cfg, motorPositionsAbsMM, motorHomeMM);
    deviceSuffix = localBuildDeviceSuffix(cfg);

    txt = sprintf('* %s (Trial=%d, ImagingMode=%s, Frames=%d, Devices=%s, MotorMode=%s, MotorTag=%s, StimBox=%d, PulsePal=%d, Motor=%d)', ...
        nameShort, ...
        iTrial, ...
        localGetImagingMode(cfg), ...
        cfg.n_frames, ...
        deviceSuffix, ...
        cfg.motor.mode, ...
        motorTag, ...
        logical(cfg.stimbox.enable), ...
        logical(cfg.pulsepal.enable), ...
        logical(cfg.motor.enable));
end


function localWriteScanInfoText(nameFile, cfg, iTrial, md)
    [folderPath, baseName, ~] = fileparts(nameFile);
    txtFile = fullfile(folderPath, [baseName '.txt']);

    fid = fopen(txtFile, 'w');
    if fid < 0
        warning('Could not create scan info txt file: %s', txtFile);
        return;
    end

    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    trSec = localCalcTRSec(cfg.nblocksImage, localGetTRUnit(cfg));

    fprintf(fid, 'Scan information\n');
    fprintf(fid, '================\n\n');

    fprintf(fid, 'Saved on: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, 'MAT file: %s\n', nameFile);
    fprintf(fid, 'Trial number: %d\n\n', iTrial);

    fprintf(fid, '[Acquisition]\n');
    fprintf(fid, 'Save owner: %s\n', localSafeText(localGetFieldIfExists(cfg, 'save_owner', 'NA')));
    fprintf(fid, 'Experiment name: %s\n', localSafeText(localGetFieldIfExists(cfg, 'xp_name', 'NA')));
    fprintf(fid, 'Imaging mode: %s\n', localGetImagingMode(cfg));
    if isfield(cfg, 'output_session_name') && ~isempty(cfg.output_session_name)
    fprintf(fid, 'Output session folder: %s\n', localSafeText(cfg.output_session_name));
end

if isfield(cfg, 'output_session_folder') && ~isempty(cfg.output_session_folder)
    fprintf(fid, 'Output session path: %s\n', localSafeText(cfg.output_session_folder));
end
    fprintf(fid, 'Frames per trial: %s\n', localNumToStr(cfg.n_frames));
    fprintf(fid, 'Number of trials: %s\n', localNumToStr(cfg.n_trials));
    fprintf(fid, 'nblocksImage: %s\n', localNumToStr(cfg.nblocksImage));
    fprintf(fid, 'Probe type: %s\n', localSafeText(cfg.probe_type));
    fprintf(fid, 'TR unit (s per block): %s\n', localNumToStr(localGetTRUnit(cfg)));
    fprintf(fid, 'TR (s): %s\n', localNumToStr(trSec));
    fprintf(fid, 'Frame rate (Hz): %s\n', localNumToStr(1 / trSec));
    fprintf(fid, 'Pause between trials (s): %s\n', localNumToStr(cfg.time_pause));
if nargin >= 4 && isstruct(md)
    fprintf(fid, '\n[Timing QC]\n');

    if isfield(md, 'requested_dt_s')
        fprintf(fid, 'Requested dt/TR (s): %s\n', localNumToStr(md.requested_dt_s));
    end
    if isfield(md, 'actual_mean_dt_s')
        fprintf(fid, 'Actual mean dt/TR (s): %s\n', localNumToStr(md.actual_mean_dt_s));
    end
    if isfield(md, 'actual_acq_elapsed_s')
        fprintf(fid, 'Actual acquisition elapsed time (s): %s\n', localNumToStr(md.actual_acq_elapsed_s));
    end
    if isfield(md, 'actual_frames_saved')
        fprintf(fid, 'Actual frames saved: %s\n', localNumToStr(md.actual_frames_saved));
    end
    if isfield(md, 'actual_dt_deviation_percent')
        fprintf(fid, 'Actual dt deviation (percent): %s\n', localNumToStr(md.actual_dt_deviation_percent));
    end
    if isfield(md, 'highres_total_elapsed_s')
        fprintf(fid, 'High-res total acquisition + reconstruction time (s): %s\n', ...
            localNumToStr(md.highres_total_elapsed_s));
    end
end
    fprintf(fid, '\n[StimBox]\n');
    fprintf(fid, 'Enabled: %s\n', localOnOff(cfg.stimbox.enable));
    fprintf(fid, 'COM: %s\n', localSafeText(cfg.stimbox.com));
    fprintf(fid, 'Baud: %s\n', localNumToStr(cfg.stimbox.baud));
    fprintf(fid, 'Frame start: %s\n', localNumToStr(cfg.stimbox.start_frame));
    fprintf(fid, 'Frames active: %s\n', localNumToStr(cfg.stimbox.frame_duration));
    fprintf(fid, 'Repeat enabled: %s\n', localOnOff(cfg.stimbox.repeat_enable));
    fprintf(fid, 'Repeat every frames: %s\n', localNumToStr(cfg.stimbox.repeat_interval_frames));
    fprintf(fid, 'D3 enabled: %s\n', localOnOff(cfg.stimbox.d3_enable));
    fprintf(fid, 'D5 enabled: %s\n', localOnOff(cfg.stimbox.d5_enable));
    fprintf(fid, 'D6 enabled: %s\n', localOnOff(cfg.stimbox.d6_enable));
    fprintf(fid, 'Verbose log: %s\n', localOnOff(cfg.stimbox.verbose));

    fprintf(fid, '\n[Electrical Stimulation / PulsePal]\n');
    fprintf(fid, 'Enabled: %s\n', localOnOff(cfg.pulsepal.enable));
    fprintf(fid, 'COM: %s\n', localSafeText(cfg.pulsepal.com));
    fprintf(fid, 'Channel: %s\n', localNumToStr(cfg.pulsepal.channel));
    fprintf(fid, 'Frame start: %s\n', localNumToStr(cfg.pulsepal.start_frame));
    fprintf(fid, 'Frames active: %s\n', localNumToStr(cfg.pulsepal.frame_duration));
    fprintf(fid, 'Repeat enabled: %s\n', localOnOff(cfg.pulsepal.repeat_enable));
    fprintf(fid, 'Repeat every frames: %s\n', localNumToStr(cfg.pulsepal.repeat_interval_frames));
    fprintf(fid, 'Biphasic: %s\n', localOnOff(cfg.pulsepal.is_biphasic));
    fprintf(fid, 'Phase1 voltage (V): %s\n', localNumToStr(cfg.pulsepal.phase1_voltage));
    fprintf(fid, 'Phase1 duration (s): %s\n', localNumToStr(cfg.pulsepal.phase1_duration_s));
    fprintf(fid, 'Interphase interval (s): %s\n', localNumToStr(cfg.pulsepal.interphase_interval_s));
    fprintf(fid, 'Phase2 voltage (V): %s\n', localNumToStr(cfg.pulsepal.phase2_voltage));
    fprintf(fid, 'Phase2 duration (s): %s\n', localNumToStr(cfg.pulsepal.phase2_duration_s));
    fprintf(fid, 'Resting voltage (V): %s\n', localNumToStr(cfg.pulsepal.resting_voltage));
    fprintf(fid, 'Interpulse interval (s): %s\n', localNumToStr(cfg.pulsepal.interpulse_interval_s));
    fprintf(fid, 'Burst duration (s): %s\n', localNumToStr(cfg.pulsepal.burst_duration_s));
    fprintf(fid, 'Interburst interval (s): %s\n', localNumToStr(cfg.pulsepal.interburst_interval_s));
    fprintf(fid, 'Train delay (s): %s\n', localNumToStr(cfg.pulsepal.train_delay_s));
    fprintf(fid, 'Train duration (s): %s\n', localNumToStr(cfg.pulsepal.train_duration_s));

       fprintf(fid, '\n[Step Motor]\n');
    fprintf(fid, 'Enabled: %s\n', localOnOff(cfg.motor.enable));
    fprintf(fid, 'COM: %s\n', localSafeText(cfg.motor.com));

    if isfield(cfg.motor, 'acquisition_mode')
        fprintf(fid, 'Acquisition mode: %s\n', localSafeText(cfg.motor.acquisition_mode));
    else
        fprintf(fid, 'Acquisition mode: NA\n');
    end

    fprintf(fid, 'Mode: %s\n', localSafeText(cfg.motor.mode));
    fprintf(fid, 'Active from frame: %s\n', localNumToStr(cfg.motor.frame_start));
    fprintf(fid, 'Active for frames: %s\n', localNumToStr(cfg.motor.frame_duration));
    fprintf(fid, 'Repeat enabled: %s\n', localOnOff(cfg.motor.repeat_enable));
    fprintf(fid, 'Repeat every frames: %s\n', localNumToStr(cfg.motor.repeat_interval_frames));
    fprintf(fid, 'Start position (mm): %s\n', localNumToStr(cfg.motor.start_mm));
    fprintf(fid, 'End position (mm): %s\n', localNumToStr(cfg.motor.end_mm));
    fprintf(fid, 'Step size (mm): %s\n', localNumToStr(cfg.motor.step_mm));
    fprintf(fid, 'Frames per position: %s\n', localNumToStr(cfg.motor.frames_per_position));
    fprintf(fid, 'Periodic: %s\n', localOnOff(cfg.motor.periodic));
    fprintf(fid, 'Return home: %s\n', localOnOff(cfg.motor.return_to_zero));
    fprintf(fid, 'Settle pause (s): %s\n', localNumToStr(cfg.motor.settle_pause_s));
if nargin >= 4 && isstruct(md)
    fprintf(fid, '\n[Motor Reconstruction Metadata]\n');

    if isfield(md, 'motor_time_index')
        fprintf(fid, 'Motor time index: %s\n', localNumToStr(md.motor_time_index));
    end
    if isfield(md, 'motor_slice_index')
        fprintf(fid, 'Motor slice index: %s\n', localNumToStr(md.motor_slice_index));
    end
    if isfield(md, 'motor_slice_count')
        fprintf(fid, 'Motor slice count: %s\n', localNumToStr(md.motor_slice_count));
    end
    if isfield(md, 'requested_frames_this_file')
        fprintf(fid, 'Requested frames this file: %s\n', localNumToStr(md.requested_frames_this_file));
    end
    if isfield(md, 'motor_rebuild_hint')
        fprintf(fid, 'Rebuild hint: %s\n', localSafeText(md.motor_rebuild_hint));
    end
end
   fprintf(fid, '\n[User Journal Note]\n');
userNote = localGetFieldIfExists(cfg, 'journal_note', '');

if isempty(userNote)
    fprintf(fid, 'NA\n');
else
    userNote = localNormalizeJournalNote(userNote);

    if isempty(strtrim(userNote))
        fprintf(fid, 'NA\n');
    else
        fprintf(fid, '%s\n', userNote);
    end
end

    localGuiLog(cfg, sprintf('Saved scan info txt: %s', txtFile));
end

function localWriteSplitSessionSummaryText(cfg, splitSessionRows, lastNameFile, lastTrial, lastMd)

    if isfield(cfg, 'output_session_folder') && ~isempty(cfg.output_session_folder)
        folderPath = cfg.output_session_folder;
    else
        folderPath = fileparts(lastNameFile);
    end

    if isfield(cfg, 'output_session_name') && ~isempty(cfg.output_session_name)
        summaryName = [cfg.output_session_name '_summary.txt'];
    else
        summaryName = 'SplitMotor_session_summary.txt';
    end

    txtFile = fullfile(folderPath, summaryName);

    fid = fopen(txtFile, 'w');
    if fid < 0
        warning('Could not create split session summary TXT: %s', txtFile);
        return;
    end

    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    trSec = localCalcTRSec(cfg.nblocksImage, localGetTRUnit(cfg));

    fprintf(fid, 'Split motor session summary\n');
    fprintf(fid, '===========================\n\n');

    fprintf(fid, 'Saved on: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, 'Output folder: %s\n', folderPath);
    fprintf(fid, 'Experiment name: %s\n', localSafeText(cfg.xp_name));

    if isfield(cfg, 'output_session_name') && ~isempty(cfg.output_session_name)
        fprintf(fid, 'Output session: %s\n', localSafeText(cfg.output_session_name));
    end

    fprintf(fid, '\n[Acquisition]\n');
    fprintf(fid, 'Frames per trial total: %s\n', localNumToStr(cfg.n_frames));
    fprintf(fid, 'Number of trials: %s\n', localNumToStr(cfg.n_trials));
    fprintf(fid, 'nblocksImage: %s\n', localNumToStr(cfg.nblocksImage));
    fprintf(fid, 'Probe type: %s\n', localSafeText(cfg.probe_type));
    fprintf(fid, 'TR unit (s per block): %s\n', localNumToStr(localGetTRUnit(cfg)));
    fprintf(fid, 'Requested TR (s): %s\n', localNumToStr(trSec));
    fprintf(fid, 'Requested frame rate (Hz): %s\n', localNumToStr(1 / trSec));

    fprintf(fid, '\n[Step Motor]\n');
    fprintf(fid, 'Enabled: %s\n', localOnOff(cfg.motor.enable));
    fprintf(fid, 'COM: %s\n', localSafeText(cfg.motor.com));
    fprintf(fid, 'Acquisition mode: %s\n', localSafeText(cfg.motor.acquisition_mode));
    fprintf(fid, 'Mode: %s\n', localSafeText(cfg.motor.mode));
    fprintf(fid, 'Start position (mm): %s\n', localNumToStr(cfg.motor.start_mm));
    fprintf(fid, 'End position (mm): %s\n', localNumToStr(cfg.motor.end_mm));
    fprintf(fid, 'Step size (mm): %s\n', localNumToStr(cfg.motor.step_mm));
    fprintf(fid, 'Frames per position/slice file: %s\n', localNumToStr(cfg.motor.frames_per_position));
    fprintf(fid, 'Periodic: %s\n', localOnOff(cfg.motor.periodic));
    fprintf(fid, 'Settle pause (s): %s\n', localNumToStr(cfg.motor.settle_pause_s));

    if nargin >= 5 && isstruct(lastMd)
        fprintf(fid, '\n[Last file timing QC]\n');

        if isfield(lastMd, 'requested_dt_s')
            fprintf(fid, 'Requested dt/TR (s): %s\n', localNumToStr(lastMd.requested_dt_s));
        end
        if isfield(lastMd, 'actual_mean_dt_s')
            fprintf(fid, 'Actual mean dt/TR (s): %s\n', localNumToStr(lastMd.actual_mean_dt_s));
        end
        if isfield(lastMd, 'actual_acq_elapsed_s')
            fprintf(fid, 'Actual acquisition elapsed time (s): %s\n', localNumToStr(lastMd.actual_acq_elapsed_s));
        end
        if isfield(lastMd, 'actual_frames_saved')
            fprintf(fid, 'Actual frames saved: %s\n', localNumToStr(lastMd.actual_frames_saved));
        end
        if isfield(lastMd, 'actual_dt_deviation_percent')
            fprintf(fid, 'Actual dt deviation percent: %s\n', localNumToStr(lastMd.actual_dt_deviation_percent));
        end
    end

    fprintf(fid, '\n[Split files]\n');
    fprintf(fid, 'Number of MAT files: %d\n', numel(splitSessionRows));
    fprintf(fid, 'Last trial: %s\n\n', localNumToStr(lastTrial));

    for k = 1:numel(splitSessionRows)
        fprintf(fid, '%s\n', splitSessionRows{k});
    end

    fprintf(fid, '\n[User Journal Note]\n');
    userNote = localGetFieldIfExists(cfg, 'journal_note', '');

    if isempty(userNote)
        fprintf(fid, 'NA\n');
    else
        userNote = localNormalizeJournalNote(userNote);
        if isempty(strtrim(userNote))
            fprintf(fid, 'NA\n');
        else
            fprintf(fid, '%s\n', userNote);
        end
    end

    localGuiLog(cfg, sprintf('Saved final split session summary TXT: %s', txtFile));
end


function s = localMotorTag(cfg, motorPositionsAbsMM, motorHomeMM)
    if ~cfg.motor.enable
        s = 'MOTOROFF';
        return;
    end

    if strcmpi(cfg.motor.mode, 'single')
        if isempty(motorPositionsAbsMM) || isnan(motorPositionsAbsMM(1))
            s = 'PNA';
        else
            relPosMM = motorPositionsAbsMM(1) - motorHomeMM;
            s = sprintf('P%0.3f', relPosMM);
            s = strrep(s, '-', 'm');
            s = strrep(s, '.', 'p');
        end
    else
        s = 'STEPPED';
    end
end

% =========================================================================
% Summary printing
% =========================================================================
function localPrintSummary(cfg, motorHomeMM, motorPositionsAbsMM, stimboxFrames, pulsepalTriggerFrames, motorPlan)
    trSec = localCalcTRSec(cfg.nblocksImage, localGetTRUnit(cfg));
    fps = 1 / trSec;

    disp(' ');
    disp('############################################################');
    disp('Get ready! The fUS acquisition will start shortly.');
    fprintf('- Experiment name: %s\n', cfg.xp_name);
    fprintf('- Imaging mode: %s\n', localGetImagingMode(cfg));
    fprintf('- Frames per trial: %d\n', cfg.n_frames);
    fprintf('- Number of trials: %d\n', cfg.n_trials);
    fprintf('- nblocksImage: %d\n', cfg.nblocksImage);
    fprintf('- Probe type: %s\n', cfg.probe_type);
    fprintf('- TR (%s probe, %.3f s per block): %.3f s\n', ...
        cfg.probe_type, localGetTRUnit(cfg), trSec);
    fprintf('- Frame rate: %.3f fps\n', fps);

    fprintf('- StimBox enabled: %d\n', logical(cfg.stimbox.enable));
    if cfg.stimbox.enable
        fprintf('- StimBox COM: %s\n', cfg.stimbox.com);
        fprintf('- StimBox D3 frames: %d\n', numel(stimboxFrames.d3_frames));
        fprintf('- StimBox D5 frames: %d\n', numel(stimboxFrames.d5_frames));
        fprintf('- StimBox D6 frames: %d\n', numel(stimboxFrames.d6_frames));
    end

    fprintf('- PulsePal enabled: %d\n', logical(cfg.pulsepal.enable));
    if cfg.pulsepal.enable
        fprintf('- PulsePal COM: %s\n', cfg.pulsepal.com);
        fprintf('- PulsePal channel: %d\n', cfg.pulsepal.channel);
        fprintf('- PulsePal trigger count: %d\n', numel(pulsepalTriggerFrames));
        fprintf('- Phase1Voltage: %g V\n', cfg.pulsepal.phase1_voltage);
        fprintf('- Phase1Duration: %g s\n', cfg.pulsepal.phase1_duration_s);
        fprintf('- InterPulseInterval: %g s\n', cfg.pulsepal.interpulse_interval_s);
        fprintf('- PulseTrainDuration: %g s\n', cfg.pulsepal.train_duration_s);
        fprintf('- RestingVoltage: %g V\n', cfg.pulsepal.resting_voltage);
        fprintf('- Biphasic: %d\n', logical(cfg.pulsepal.is_biphasic));
    end

    fprintf('- Motor enabled: %d\n', logical(cfg.motor.enable));
    if cfg.motor.enable
        fprintf('- Motor COM: %s\n', cfg.motor.com);
        fprintf('- Motor mode: %s\n', cfg.motor.mode);
        fprintf('- Motor home position: %.3f mm\n', motorHomeMM);

        if ~isempty(cfg.motor.start_mm) && isnumeric(cfg.motor.start_mm) && ~isnan(cfg.motor.start_mm)
            fprintf('- Motor absolute start: %.3f mm\n', cfg.motor.start_mm);
            if ~isempty(cfg.motor.end_mm) && isnumeric(cfg.motor.end_mm) && ~isnan(cfg.motor.end_mm)
                fprintf('- Motor absolute end: %.3f mm\n', cfg.motor.end_mm);
            end
        else
            fprintf('- Motor start offset: %.3f mm\n', cfg.motor.start_offset_mm);
            fprintf('- Motor end offset: %.3f mm\n', cfg.motor.end_offset_mm);
        end

        if strcmpi(cfg.motor.mode, 'stepped')
            fprintf('- Step size: %.3f mm\n', cfg.motor.step_mm);
            fprintf('- Frames per position: %d\n', round(cfg.motor.frames_per_position));
            fprintf('- Periodic within cycle: %d\n', logical(cfg.motor.periodic));
        end

        if ~isempty(motorPositionsAbsMM) && all(~isnan(motorPositionsAbsMM))
            fprintf('- Configured motor positions: %d\n', numel(motorPositionsAbsMM));
        end

        fprintf('- Used motor moves per trial: %d\n', numel(motorPlan.frames));
    end

    fprintf('- Pause between trials: %.3f s\n', cfg.time_pause);
    disp('############################################################');
    disp(' ');
end

function trSec = localCalcTRSec(nblocksImage, trUnitSec)
    % TR = nblocksImage x (seconds per block unit)
    %
    %   2D probe : 0.02 s per unit
    %   3D probe : 0.03 s per unit
    %
    % trUnitSec is optional so that any older call site still works.

    if nargin < 2 || isempty(trUnitSec) || ~isnumeric(trUnitSec) || ...
            ~isfinite(trUnitSec) || trUnitSec <= 0
        trUnitSec = 0.02;
    end

    trSec = nblocksImage * trUnitSec;
end

function trUnitSec = localGetTRUnit(cfg)
    % Resolve seconds-per-block from cfg, preferring an explicit value.

    trUnitSec = 0.02;

    try
        if isfield(cfg, 'tr_unit_s') && ~isempty(cfg.tr_unit_s) && ...
                isnumeric(cfg.tr_unit_s) && isfinite(cfg.tr_unit_s) && cfg.tr_unit_s > 0
            trUnitSec = cfg.tr_unit_s;
            return;
        end
    catch
    end

    try
        if isfield(cfg, 'probe_type') && ~isempty(cfg.probe_type) && ...
                ischar(cfg.probe_type) && ~isempty(strfind(upper(cfg.probe_type), '3D'))
            trUnitSec = 0.03;
        end
    catch
    end
end

function tf = localIs3DProbe(cfg)
    tf = false;
    try
        if isfield(cfg, 'probe_type') && ischar(cfg.probe_type) && ...
                ~isempty(strfind(upper(cfg.probe_type), '3D'))
            tf = true;
        end
    catch
    end
end

function localSafePause(t)
    if ~isempty(t) && isnumeric(t) && isfinite(t) && t > 0
        pause(t);
    end
end

function n = localGetAcquiredFrameCount(I, fallbackN)
    % Number of acquired frames / volumes.
    %
    %   2D probe : I is [Z X T]      -> last dimension is time
    %   3D probe : I is [Z X Y T]    -> last dimension is still time
    %
    % Time is the trailing dimension in both cases, so size(I, end) is used.
    % A singleton trailing dimension is the one trap: MATLAB drops it, so
    % a single-frame acquisition reports the wrong count. The fallback
    % covers that, and any implausible value is rejected.

    n = fallbackN;

    try
        sz = size(I);

        if numel(sz) >= 3
            candidate = sz(end);

            % Guard against a dropped singleton time dimension.
            if numel(sz) == 3 && fallbackN == 1
                candidate = fallbackN;
            end

            n = candidate;
        end

        if isempty(n) || ~isnumeric(n) || ~isscalar(n) || isnan(n) || n < 1
            n = fallbackN;
        end
    catch
        n = fallbackN;
    end
end

% =========================================================================
% GUI bridge
% =========================================================================
function tf = localStopRequested(cfg)
    tf = false;
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'stopRequestedFcn')
        try
            tf = logical(cfg.gui.stopRequestedFcn());
        catch
            tf = false;
        end
    end
end

function localGuiStatus(cfg, msg, state)
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'statusFcn')
        try
            cfg.gui.statusFcn(msg, state);
        catch
        end
    end
end

function localGuiLog(cfg, msg)
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'logFcn')
        try
            cfg.gui.logFcn(msg);
        catch
        end
    end
end

function localGuiPreview(cfg,I,mode,md)
    try
        if isfield(cfg,'gui') && isstruct(cfg.gui) && ...
                isfield(cfg.gui,'previewFcn') && isa(cfg.gui.previewFcn,'function_handle')
            cfg.gui.previewFcn(I,mode,md);
        end
    catch
    end
end

function localGuiFrame(cfg, frameIdx)
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'frameFcn')
        try
            cfg.gui.frameFcn(frameIdx);
        catch
        end
    end
end

function localGuiTrial(cfg, iTrial, nTrials)
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'trialFcn')
        try
            cfg.gui.trialFcn(iTrial, nTrials);
        catch
        end
    end
end

function localGuiMotor(cfg, moveCount, total, absPosMM, frameIdx)
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'motorStepFcn')
        try
            cfg.gui.motorStepFcn(moveCount, total, absPosMM, frameIdx);
        catch
        end
    end
end




function localOpenPulsePalRobust(comName)
    % Force-close any stale MATLAB PulsePal session first
    localClosePulsePalRobust();
    localKillCOMPortRobust(comName);
    pause(0.30);

    lastErr = '';

    for k = 1:3
        try
            PulsePal(comName);
            pause(0.50);

            % If PulsePal opened without throwing an error,
            % accept that as connected for this toolbox version.
            try
                PulsePalDisplay('MATLAB commanded');
            catch
            end
            return;

        catch ME
            lastErr = ME.message;
        end

        localClosePulsePalRobust();
        localKillCOMPortRobust(comName);
        pause(0.40);
    end

    error('Could not initialize PulsePal on %s. Last error: %s', comName, lastErr);
end

function localKillCOMPortRobust(comName)
    try
        oldObj = instrfind('Port', comName);
        if ~isempty(oldObj)
            for i = 1:numel(oldObj)
                try
                    if strcmpi(get(oldObj(i), 'Status'), 'open')
                        fclose(oldObj(i));
                    end
                catch
                end
                try
                    delete(oldObj(i));
                catch
                end
            end
        end
    catch
    end

    try
        if exist('serialportfind', 'file') == 2 || exist('serialportfind', 'builtin') == 5
            sp = serialportfind("Port", comName);
            if ~isempty(sp)
                for i = 1:numel(sp)
                    try
                        delete(sp(i));
                    catch
                    end
                end
            end
        end
    catch
    end
end


function localBootstrapPulsePalDefaults()
    S = [];

    % First try if the example MAT is already on the MATLAB path
    try
        exFile = which('PulsePalProgram_Example.mat');
    catch
        exFile = '';
    end

    % If not on path, try PulsePal toolbox Programs folder
    if isempty(exFile)
        try
            ppFile = which('PulsePal');
            ppRoot = fileparts(ppFile);
            exFile = fullfile(ppRoot, 'Programs', 'PulsePalProgram_Example.mat');
            if ~exist(exFile, 'file')
                exFile = '';
            end
        catch
            exFile = '';
        end
    end

    if isempty(exFile)
        error(['Could not find PulsePalProgram_Example.mat. ' ...
               'Add the PulsePal Programs folder to the MATLAB path, or place the MAT file on path.']);
    end

    S = load(exFile);

    if ~isfield(S, 'ParameterMatrix')
        error('PulsePalProgram_Example.mat does not contain ParameterMatrix.');
    end

    ProgramPulsePal(S.ParameterMatrix);
    pause(0.10);
end


function tf = localIsPulsePalReady()
    global PulsePalSystem
    tf = false;

    try
        if isempty(PulsePalSystem)
            return;
        end
    catch
        return;
    end

    % Accept either classic struct-like API or object-like API
    try
        if isstruct(PulsePalSystem)
            tf = isfield(PulsePalSystem, 'Params');
            return;
        end
    catch
    end

    try
        tf = isprop(PulsePalSystem, 'Params');
        if tf
            return;
        end
    catch
    end

    % Last fallback: if ProgramPulsePalParam exists, we can still try it
    try
        tf = (exist('ProgramPulsePalParam', 'file') == 2);
    catch
        tf = false;
    end
end

function localClosePulsePalRobust()
    global PulsePalSystem

    try
        AbortPulsePal;
    catch
    end

    try
        EndPulsePal;
    catch
    end

    pause(0.20);

    try
        clear global PulsePalSystem
    catch
    end

    try
        PulsePalSystem = [];
    catch
    end
end

function localProgramPulsePal(cfg)
    ch = round(cfg.pulsepal.channel);

    if ch < 1 || ch > 4
        error('PulsePal channel must be 1..4.');
    end

    try
        AbortPulsePal;
    catch
    end

    % Selected output channel parameters
    localProgramPulsePalParamChecked(ch, 'IsBiphasic',         double(logical(cfg.pulsepal.is_biphasic)));
    localProgramPulsePalParamChecked(ch, 'Phase1Voltage',      cfg.pulsepal.phase1_voltage);
    localProgramPulsePalParamChecked(ch, 'Phase2Voltage',      cfg.pulsepal.phase2_voltage);
    localProgramPulsePalParamChecked(ch, 'RestingVoltage',     cfg.pulsepal.resting_voltage);

    localProgramPulsePalParamChecked(ch, 'Phase1Duration',     cfg.pulsepal.phase1_duration_s);
    localProgramPulsePalParamChecked(ch, 'InterPhaseInterval', cfg.pulsepal.interphase_interval_s);
    localProgramPulsePalParamChecked(ch, 'Phase2Duration',     cfg.pulsepal.phase2_duration_s);
    localProgramPulsePalParamChecked(ch, 'InterPulseInterval', cfg.pulsepal.interpulse_interval_s);

    localProgramPulsePalParamChecked(ch, 'BurstDuration',      cfg.pulsepal.burst_duration_s);
    localProgramPulsePalParamChecked(ch, 'InterBurstInterval', cfg.pulsepal.interburst_interval_s);
    localProgramPulsePalParamChecked(ch, 'PulseTrainDelay',    cfg.pulsepal.train_delay_s);
    localProgramPulsePalParamChecked(ch, 'PulseTrainDuration', cfg.pulsepal.train_duration_s);

    % Keep external/custom features OFF in current workflow
    try, localProgramPulsePalParamChecked(ch, 'CustomTrainID', 0);       catch, end
    try, localProgramPulsePalParamChecked(ch, 'CustomTrainTarget', 0);   catch, end
    try, localProgramPulsePalParamChecked(ch, 'CustomTrainLoop', 0);     catch, end
    try, localProgramPulsePalParamChecked(ch, 'LinkedToTriggerCH1', 0);  catch, end
    try, localProgramPulsePalParamChecked(ch, 'LinkedToTriggerCH2', 0);  catch, end

    % Trigger channel modes off
    try, localProgramPulsePalParamChecked(1, 'TriggerMode', 0); catch, end
    try, localProgramPulsePalParamChecked(2, 'TriggerMode', 0); catch, end

    try
        SyncPulsePalParams;
    catch
    end

    try
        SetContinuousPlay(ch, 0);
    catch
        try
            SetContinuousLoop(ch, 0);
        catch
        end
    end

    try
        PulsePalDisplay('MATLAB commanded');
    catch
    end
end

function localGuiTiming(cfg, requestedDtSec, actualMeanDtSec, devPct, acqElapsedSec, actualFrames)
    if isfield(cfg, 'gui') && isstruct(cfg.gui) && isfield(cfg.gui, 'timingFcn')
        try
            cfg.gui.timingFcn(requestedDtSec, actualMeanDtSec, devPct, acqElapsedSec, actualFrames);
        catch
        end
    end
end

function motorMode = localGetMotorAcqMode(cfg)

    motorMode = 'off';

    try
        if ~isfield(cfg, 'motor') || ~isstruct(cfg.motor) || ...
                ~isfield(cfg.motor, 'enable') || ~logical(cfg.motor.enable)
            return;
        end

        if isfield(cfg.motor, 'acquisition_mode') && ~isempty(cfg.motor.acquisition_mode)
            if strcmpi(cfg.motor.acquisition_mode, 'continuous')
                motorMode = 'continuous';
            elseif strcmpi(cfg.motor.acquisition_mode, 'split')
                motorMode = 'split';
            else
                motorMode = 'split';
            end
        else
            motorMode = 'split';
        end
    catch
        motorMode = 'split';
    end
end

function localProgramPulsePalParamChecked(channel, paramName, value)
    try
        confirmBit = ProgramPulsePalParam(channel, paramName, value);
    catch ME
        error('ProgramPulsePalParam failed for %s on channel %d: %s', ...
            paramName, channel, ME.message);
    end

    if isnumeric(confirmBit) && isscalar(confirmBit) && confirmBit == 0
        error('PulsePal rejected parameter %s on channel %d.', paramName, channel);
    end
end
function tf = localShouldUseProcessRF(cfg)

    tf = false;

    % Needed for frame-synchronized StimBox.
    try
        if isfield(cfg, 'stimbox') && isstruct(cfg.stimbox) && logical(cfg.stimbox.enable)
            tf = true;
            return;
        end
    catch
    end

    % Needed for frame-synchronized PulsePal.
    try
        if isfield(cfg, 'pulsepal') && isstruct(cfg.pulsepal) && logical(cfg.pulsepal.enable)
            tf = true;
            return;
        end
    catch
    end

    % Needed for continuous motor mode because motor moves inside the scan.
    try
        if isfield(cfg, 'motor') && isstruct(cfg.motor) && ...
                logical(cfg.motor.enable) && ...
                isfield(cfg.motor, 'acquisition_mode') && ...
                strcmpi(cfg.motor.acquisition_mode, 'continuous')
            tf = true;
            return;
        end
    catch
    end

    % Optional GUI-only live frame updates.
    % Keep this false if you care about TR.
    try
        if isfield(cfg, 'gui') && isstruct(cfg.gui) && ...
                isfield(cfg.gui, 'forceProcessRFForLiveFrames') && ...
                logical(cfg.gui.forceProcessRFForLiveFrames)
            tf = true;
            return;
        end
    catch
    end
end
function plan = localBuildContinuousMotorCallbackPlan(motorCfg, positionsAbsMM, nFrames)

    plan = struct();
    plan.frames = [];
    plan.targets_abs_mm = [];

    if isempty(positionsAbsMM) || any(isnan(positionsAbsMM))
        return;
    end

    nPos = numel(positionsAbsMM);
    if nPos < 2
        return;
    end

    framesPerSlice = max(1, round(motorCfg.frames_per_position));

    startFrame = 1;
    if isfield(motorCfg, 'frame_start') && ~isempty(motorCfg.frame_start) && ...
            isnumeric(motorCfg.frame_start) && isfinite(motorCfg.frame_start)
        startFrame = max(1, round(motorCfg.frame_start));
    end

    nFrames = max(1, round(nFrames));

    % We pre-move to slice 1 before SCAN.doppler.
    % Therefore first motor move during acquisition is to slice 2.
    maxMoveSlots = floor((nFrames - startFrame) / framesPerSlice);

    if maxMoveSlots < 1
        return;
    end

    if isfield(motorCfg, 'periodic') && logical(motorCfg.periodic)
        nMoves = maxMoveSlots;
    else
        nMoves = min(maxMoveSlots, nPos - 1);
    end

    for k = 1:nMoves
        moveFrame = startFrame + k * framesPerSlice;

        if moveFrame > nFrames
            continue;
        end

        if isfield(motorCfg, 'periodic') && logical(motorCfg.periodic)
            targetIdx = mod(k, nPos) + 1;
        else
            targetIdx = k + 1;
        end

        plan.frames(end+1) = moveFrame; %#ok<AGROW>
        plan.targets_abs_mm(end+1) = positionsAbsMM(targetIdx); %#ok<AGROW>
    end
end

function localPPSet(channelOrTrig, paramName, paramValue)
    confirmBit = ProgramPulsePalParam(channelOrTrig, paramName, paramValue);

    if isempty(confirmBit) || ~isequal(confirmBit, 1)
        error('PulsePal failed while programming parameter "%s".', paramName);
    end
end
% =========================================================================
% Small utilities
% =========================================================================
function cfg = localPrepareSplitMotorSessionFolder(cfg, sessionTag)

    if ~isfield(cfg, 'save_owner') || isempty(cfg.save_owner)
        cfg.save_owner = 'Soner';
    end

    % HUMOR_OUTPUT_ROOT_CDATA_V1
if isfield(cfg, 'output_root') && ~isempty(cfg.output_root)
    outputRoot = cfg.output_root;
else
    outputRoot = 'C:\Data';
end
baseFolder = fullfile(outputRoot, cfg.save_owner, cfg.xp_name);

    if ~exist(baseFolder, 'dir')
        mkdir(baseFolder);
    end

    cfg.output_base_folder = baseFolder;
    cfg.output_session_folder = '';
    cfg.output_session_name = '';
    cfg.output_session_tag = sessionTag;

    useSplitMotor = false;

    try
        useSplitMotor = ...
            isfield(cfg, 'motor') && isstruct(cfg.motor) && ...
            isfield(cfg.motor, 'enable') && logical(cfg.motor.enable) && ...
            isfield(cfg.motor, 'acquisition_mode') && ...
            strcmpi(cfg.motor.acquisition_mode, 'split');
    catch
        useSplitMotor = false;
    end

    if ~useSplitMotor
        return;
    end

    sessionIdx = localGetNextSplitMotorSessionIndex(baseFolder);

    sessionName = sprintf('Session_%03d_SplitMotor', sessionIdx);
    sessionFolder = fullfile(baseFolder, sessionName);

    if ~exist(sessionFolder, 'dir')
        mkdir(sessionFolder);
    end

    cfg.output_session_name = sessionName;
    cfg.output_session_folder = sessionFolder;
end

function sessionIdx = localGetNextSplitMotorSessionIndex(baseFolder)

    sessionIdx = 1;

    if ~exist(baseFolder, 'dir')
        return;
    end

    d = dir(fullfile(baseFolder, 'Session_*_SplitMotor*'));

    nums = [];

    for i = 1:numel(d)
        if ~d(i).isdir
            continue;
        end

        tok = regexp(d(i).name, '^Session_(\d+)_SplitMotor', 'tokens', 'once');

        if ~isempty(tok)
            n = str2double(tok{1});
            if ~isnan(n)
                nums(end+1) = n; %#ok<AGROW>
            end
        end
    end

    if ~isempty(nums)
        sessionIdx = max(nums) + 1;
    end
end

function localSetObjPropIfExists(obj, propName, propValue)
    try
        if isprop(obj, propName)
            obj.(propName) = propValue;
        end
    catch
    end
end

function frames = localBuildBlockFrameList(startFrame, durationFrames, repeatOn, repeatEvery, nFrames)
    frames = [];

    if isempty(startFrame) || ~isnumeric(startFrame) || isnan(startFrame)
        return;
    end

    startFrame = round(startFrame);
    if startFrame < 1 || startFrame > nFrames
        return;
    end

    if isempty(durationFrames) || ~isnumeric(durationFrames) || isnan(durationFrames) || durationFrames < 1
        durationFrames = 1;
    end
    durationFrames = max(1, round(durationFrames));

    if ~repeatOn || isempty(repeatEvery) || ~isnumeric(repeatEvery) || isnan(repeatEvery) || repeatEvery < 1
        blockStarts = startFrame;
    else
        repeatEvery = max(1, round(repeatEvery));
        blockStarts = startFrame:repeatEvery:nFrames;
    end

    for k = 1:numel(blockStarts)
        s0 = round(blockStarts(k));
        s1 = min(nFrames, s0 + durationFrames - 1);
        frames = [frames s0:s1]; %#ok<AGROW>
    end

    frames = unique(localCleanFrameVector(frames, nFrames), 'stable');
end

function frames = localCleanFrameVector(framesIn, nFrames)
    if isempty(framesIn) || ~isnumeric(framesIn)
        frames = [];
        return;
    end

    frames = unique(round(framesIn(:)'));
    frames = frames(isfinite(frames));
    frames = frames(frames >= 1 & frames <= nFrames);
end

function v = localGetNumericField(S, names, defaultVal)
    v = defaultVal;
    if ~isstruct(S)
        return;
    end

    for i = 1:numel(names)
        if isfield(S, names{i}) && ~isempty(S.(names{i}))
            v = S.(names{i});
            return;
        end
    end
end

function tf = localGetLogicalField(S, names, defaultVal)
    tf = defaultVal;
    if ~isstruct(S)
        return;
    end

    for i = 1:numel(names)
        if isfield(S, names{i}) && ~isempty(S.(names{i}))
            try
                tf = logical(S.(names{i}));
            catch
                tf = defaultVal;
            end
            return;
        end
    end
end

function legacySpec = localFramesToLegacySpec(frames, nFrames)
    legacySpec = NaN;

    if isempty(frames)
        return;
    end

    frames = unique(frames(:)');

    if isequal(frames, 1:nFrames)
        legacySpec = -1;
    elseif numel(frames) == 1
        legacySpec = frames(1);
    else
        legacySpec = NaN;
    end
end

function legacyStart = localFramesToLegacyPulsePalStart(frames)
    legacyStart = NaN;
    if isempty(frames)
        return;
    end
    legacyStart = frames(1);
end

function txt = localStimBoxSummaryText(cfg, stimboxFrames)
    nTotal = numel(unique([stimboxFrames.d3_frames stimboxFrames.d5_frames stimboxFrames.d6_frames]));
    activeLines = {};
    if cfg.stimbox.d3_enable, activeLines{end+1} = 'D3'; end %#ok<AGROW>
    if cfg.stimbox.d5_enable, activeLines{end+1} = 'D5'; end %#ok<AGROW>
    if cfg.stimbox.d6_enable, activeLines{end+1} = 'D6'; end %#ok<AGROW>
    if isempty(activeLines)
        activeTxt = 'none';
    else
        activeTxt = strjoin(activeLines, ',');
    end
    txt = sprintf('StimBox summary: start=%s, duration=%s, repeat=%d, repeatEvery=%s, unique trigger frames=%d, lines=%s', ...
        localNumToStr(cfg.stimbox.start_frame), ...
        localNumToStr(cfg.stimbox.frame_duration), ...
        logical(cfg.stimbox.repeat_enable), ...
        localNumToStr(cfg.stimbox.repeat_interval_frames), ...
        nTotal, activeTxt);
end

function txt = localNormalizeJournalNote(noteIn)
    if isempty(noteIn)
        txt = '';
        return;
    end

    if isstring(noteIn)
        noteIn = char(noteIn);
    end

    if ischar(noteIn)
        % If noteIn is a multi-row char array, convert each row into a line
        if size(noteIn, 1) > 1
            rows = cellstr(noteIn);
            rows = rows(:)';
            txt = strjoin(rows, newline);
        else
            txt = noteIn;
        end
    else
        txt = '';
    end
end

function s = localOnOff(tf)
    if isempty(tf) || ~logical(tf)
        s = 'OFF';
    else
        s = 'ON';
    end
end

function s = localSafeText(v)
    if isempty(v)
        s = 'NA';
        return;
    end

    if ischar(v)
        s = v;
    elseif isstring(v)
        s = char(v);
    else
        s = 'NA';
    end
end

function v = localGetFieldIfExists(S, fieldName, defaultVal)
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        v = S.(fieldName);
    else
        v = defaultVal;
    end
end


function txt = localPulsePalSummaryText(cfg, pulsepalFrames)
    txt = sprintf('PulsePal summary: start=%s, repeat=%d, repeatEvery=%s, trigger count=%d, channel=%d', ...
        localNumToStr(cfg.pulsepal.start_frame), ...
        logical(cfg.pulsepal.repeat_enable), ...
        localNumToStr(cfg.pulsepal.repeat_interval_frames), ...
        numel(pulsepalFrames), ...
        cfg.pulsepal.channel);
end

function txt = localMotorSummaryText(cfg, motorHomeMM, motorPositionsAbsMM, motorPlan)
    if isempty(motorPositionsAbsMM) || all(isnan(motorPositionsAbsMM))
        txt = 'Motor summary: no valid positions.';
        return;
    end

    txt = sprintf('Motor summary: home=%.3f mm, start=%.3f mm, end=%.3f mm, positions=%d, used moves=%d', ...
        motorHomeMM, motorPositionsAbsMM(1), motorPositionsAbsMM(end), ...
        numel(motorPositionsAbsMM), numel(motorPlan.frames));
end

function s = localNumToStr(v)
    if isempty(v) || ~isnumeric(v) || isnan(v)
        s = 'NA';
    else
        s = sprintf('%g', v);
    end
end

% =========================================================================
% HUMOR_ECHOSCAN_AND_TRIGGER_HELPERS_V1
% =========================================================================
function [SCAN, FS] = localResolveScannerAndFileService(cfg)
    SCAN = [];
    FS = [];
    scanErr = '';

    % 1) Prefer objects explicitly passed by an encrypted/company launcher.
    try
        if isfield(cfg,'SCAN') && ~isempty(cfg.SCAN)
            SCAN = cfg.SCAN;
            localGuiLog(cfg, 'Using SCAN object from cfg.SCAN.');
        end
    catch ME
        scanErr = ME.message;
    end

    % 2) Try base workspace object, useful when encrypted launcher creates SCAN globally.
    if isempty(SCAN)
        try
            SCAN = evalin('base', 'SCAN');
            if ~isempty(SCAN)
                localGuiLog(cfg, 'Using SCAN object from base workspace.');
            end
        catch ME
            scanErr = ME.message;
        end
    end

    % 3) Fall back to direct company API call, as in original AUTC script.
    if isempty(SCAN)
        try
            SCAN = echoScan;
            localGuiLog(cfg, 'Created SCAN using echoScan.');
        catch ME
            scanErr = ME.message;
        end
    end

    if isempty(SCAN)
        error(['Cannot create/access echoScan scanner object.' sprintf('\n\n') ...
               'The original company script requires: SCAN = echoScan;' sprintf('\n') ...
               'This only works if the OpenfUS/PILOT encrypted launcher or scanner toolbox exposes echoScan.' sprintf('\n\n') ...
               'Fix options:' sprintf('\n') ...
               '  1) Start this GUI from the company encrypted launcher / MODE GUI, not from a plain MATLAB path.' sprintf('\n') ...
               '  2) Add the folder/toolbox that provides echoScan to the MATLAB path.' sprintf('\n') ...
               '  3) If the launcher creates SCAN internally, modify the launcher to pass cfg.SCAN = SCAN before calling this command.' sprintf('\n\n') ...
               'Last echoScan error: ' scanErr]);
    end

    % File service. Use fService if available; otherwise use a lightweight fallback journal writer.
    try
        if isfield(cfg,'FS') && ~isempty(cfg.FS)
            FS = cfg.FS;
            localGuiLog(cfg, 'Using FS object from cfg.FS.');
        end
    catch
    end

    if isempty(FS)
        try
            FS = evalin('base', 'FS');
            if ~isempty(FS)
                localGuiLog(cfg, 'Using FS object from base workspace.');
            end
        catch
        end
    end

    if isempty(FS)
        try
            FS = fService();
            localGuiLog(cfg, 'Created FS using fService.');
        catch MEfs
            localGuiLog(cfg, sprintf('fService unavailable; using fallback journal writer: %s', MEfs.message));
            FS = struct();
            FS.writeJournal = @(txt)localFallbackWriteJournal(txt, cfg);
        end
    end
end

function localFallbackWriteJournal(txt, cfg)
    try
        if ~isfield(cfg, 'save_owner') || isempty(cfg.save_owner)
            saveOwner = 'Soner';
        else
            saveOwner = cfg.save_owner;
        end
        if ~isfield(cfg, 'xp_name') || isempty(cfg.xp_name)
            xpName = 'Data_w_Triggers';
        else
            xpName = cfg.xp_name;
        end
        % HUMOR_OUTPUT_ROOT_CDATA_FALLBACK_V1
        if isfield(cfg, 'output_root') && ~isempty(cfg.output_root)
            outputRoot = cfg.output_root;
        else
            outputRoot = 'C:\Data';
        end
        outDir = fullfile(outputRoot, saveOwner, xpName);
        if exist(outDir,'dir') ~= 7
            mkdir(outDir);
        end
        jf = fullfile(outDir, 'journal_fallback.txt');
        fid = fopen(jf, 'a');
        if fid > 0
            fprintf(fid, '[%s] %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'), txt);
            fclose(fid);
        end
    catch
    end
end

function out = localShiftStimBoxFramesToCurrentAcq(inFrames, globalOffset, nFramesThisAcq)
    out = struct();
    out.d3_frames = [];
    out.d5_frames = [];
    out.d6_frames = [];
    try
        if isstruct(inFrames)
            if isfield(inFrames,'d3_frames')
                out.d3_frames = localShiftFrameVectorToCurrentAcq(inFrames.d3_frames, globalOffset, nFramesThisAcq);
            end
            if isfield(inFrames,'d5_frames')
                out.d5_frames = localShiftFrameVectorToCurrentAcq(inFrames.d5_frames, globalOffset, nFramesThisAcq);
            end
            if isfield(inFrames,'d6_frames')
                out.d6_frames = localShiftFrameVectorToCurrentAcq(inFrames.d6_frames, globalOffset, nFramesThisAcq);
            end
        end
    catch
    end
end

function localFrames = localShiftFrameVectorToCurrentAcq(globalFrames, globalOffset, nFramesThisAcq)
    localFrames = [];
    if isempty(globalFrames) || ~isnumeric(globalFrames)
        return;
    end
    globalFrames = unique(round(globalFrames(:)'));
    globalFrames = globalFrames(isfinite(globalFrames));
    localFrames = globalFrames - round(globalOffset);
    localFrames = unique(localFrames(localFrames >= 1 & localFrames <= round(nFramesThisAcq)), 'stable');
end

end