function subj=fusiFCExcludeNonTissue(subj)
% Rebuild on the functional grid without rejecting low / negative PSC means.
valid=subj.referenceValid;
if isempty(valid),valid=isfinite(subj.referenceMean);end
if isempty(valid)&&~isempty(subj.I4),valid=isfinite(mean(subj.I4,4));end
if isempty(valid),return;end
switch subj.maskPolicy
 case 'provided'
  assert(isequal(size(subj.baseMask,[1 2 3]),size(valid,[1 2 3])), ...
   'deConfUSIon:FCMaskGrid','Mask and functional recording must share the same spatial grid. Load a mask from this scan or its registered native grid.');
  subj.mask=logical(subj.baseMask)&valid;subj.maskSource='Loaded / provided include mask';
 case 'none'
  subj.mask=valid;subj.maskSource='No intensity mask; valid signal and CSF exclusions';
 otherwise
  subj.mask=valid;subj.maskSource='Automatic: finite, varying signal (no intensity cutoff)';
  % A partially covered atlas must not silently crop seed FC to its labels.
  % Region extraction still requires an atlas ID; seed FC uses valid tissue.
end
if ~isempty(subj.atlasExcludedMask),subj.mask(subj.atlasExcludedMask)=false;end
if isempty(subj.roiAtlas),return;end
T=subj.roiNameTable;excluded=997;
if isstruct(T)&&isfield(T,'labels')&&isfield(T,'names')
 for k=1:min(numel(T.labels),numel(T.names))
  name=char(T.names{k});if isfield(T,'fullNames')&&k<=numel(T.fullNames),name=[name ' ' char(T.fullNames{k})];end
  if ~isempty(regexpi(name,'\<ventricles?\>|\<ventricular (system|space|cavity)|cerebral aqueduct|choroid plexus|\<background\>|\<root\>','once'))
   excluded(end+1)=abs(double(T.labels(k))); %#ok<AGROW>
  end
 end
end
subj.mask(ismember(abs(subj.roiAtlas),excluded))=false;
end
