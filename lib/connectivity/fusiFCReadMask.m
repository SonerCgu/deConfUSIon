function mask=fusiFCReadMask(payload,targetSize)
% Decode include/exclude semantics while keeping the saved spatial grid.
bundle=scmReadMaskEditorBundle(payload);mask=[];name='';
if ~isempty(bundle)
 mask=bundle.includeMask;
else
 for field={'includeMask','mask','brainMask','loadedMask','activeMask','underlayMask'}
  if isfield(payload,field{1})&&~isempty(payload.(field{1})),name=field{1};mask=payload.(name);break;end
 end
 if isempty(mask)
  names=fieldnames(payload);
  if numel(names)==1,name=names{1};mask=payload.(name);end
 end
 assert(isnumeric(mask)||islogical(mask),'deConfUSIon:FCMaskInput','Select an include/exclude mask MAT file or Mask Editor bundle.');
 mask=isfinite(mask)&mask~=0;
 flag=[name 'IsInclude'];
 if isfield(payload,flag)&&~logical(payload.(flag)),mask=~mask;
 elseif ~isfield(payload,flag)&&isfield(payload,'maskIsInclude')&&~logical(payload.maskIsInclude),mask=~mask;end
end
assert(~isempty(mask),'deConfUSIon:FCMaskInput','The selected Mask Editor file has no drawn mask.');
assert(ndims(mask)<=3&&isequal(size(mask,[1 2 3]),double(targetSize(:)')), ...
 'deConfUSIon:FCMaskGrid','Saved mask grid %s differs from functional grid %s. Select the matching mask; FC does not resize or transpose it.', ...
 mat2str(size(mask,[1 2 3])),mat2str(targetSize));
mask=logical(mask);
end
