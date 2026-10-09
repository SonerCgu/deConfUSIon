function fusiVolumeRememberCamera(viewer,event)
% Persist a native viewer3d camera event for subsequent edits and export.
names={'CameraPosition','CameraTarget','CameraUpVector','CameraZoom'};
values=cell(size(names));
for k=1:numel(names)
    value=event.(names{k});
    expected=3;if k==4,expected=1;end
    if ~isnumeric(value) || ~isreal(value) || numel(value)~=expected || any(~isfinite(value),'all')
        error('deConfUSIon:VolumeCamera','Invalid interactive camera coordinates.');
    end
    values{k}=double(reshape(value,1,[]));
end
if norm(values{1}-values{2})==0 || norm(values{3})==0 || values{4}<=0
    error('deConfUSIon:VolumeCamera','Invalid interactive camera direction or zoom.');
end
for k=1:numel(names),viewer.(names{k})=values{k};end
end
