function vfusiValidateSensoryScan(cfg)
if strcmp(cfg.sensory.mode,'disabled'),return;end
if ~any(strcmpi(cfg.acquisition_mode,{'functional','doppler'})) || cfg.motor.enable
    error('vfUSI:SensoryScanMode','Sensory sessions require functional/Doppler acquisition with Motor disabled. Other existing scan modes remain available with sensory disabled.');
end
p=jsondecode(fileread(cfg.sensory.protocol_file));
names={'baseline_s','stimulus_s','recovery_s','repetitions','directions_deg'};
for k=1:numel(names),if ~isfield(p,names{k}),error('vfUSI:SensoryProtocol','Missing protocol field: %s',names{k});end,end
if ~all(cellfun(@(n)isnumeric(p.(n))&&isscalar(p.(n)),names(1:4)))
    error('vfUSI:SensoryProtocol','Durations and repetition count must be numeric scalars.');
end
times=[p.baseline_s p.stimulus_s p.recovery_s];
if any(~isfinite(times)|times<0)||p.stimulus_s<=0||~isfinite(p.repetitions)||p.repetitions<1||p.repetitions~=round(p.repetitions)||~isnumeric(p.directions_deg)||isempty(p.directions_deg)||any(~isfinite(p.directions_deg(:)))
    error('vfUSI:SensoryProtocol','Invalid stimulus durations, repetitions or directions.');
end
required=sum(times)*p.repetitions*numel(p.directions_deg);
tr=cfg.nblocksImage*cfg.tr_unit_s;
% The first callback can occur after the first acquired frame has completed.
available=(cfg.n_frames-1)*tr;
if required>available+1e-6
    error('vfUSI:SensoryDuration','Protocol needs %.3g s after the first callback. Use at least %d scan frames at TR %.3g s, or shorten the protocol.',required,ceil(required/tr)+1,tr);
end
end
