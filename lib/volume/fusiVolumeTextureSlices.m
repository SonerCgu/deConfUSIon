function fusiVolumeTextureSlices(ax,volume,viewer,viewportSize)
% Synchronous OpenGL volume compositing for movies. Texture every acquired
% voxel plane, retaining the displayed RGB, alpha and physical transform.
% This is a slice compositor rather than viewer3d's asynchronous ray caster.
A=double(volume.Transformation.A);sz=size(volume.AlphaData);sz(end+1:3)=1;
direction=double(viewer.CameraTarget-viewer.CameraPosition);direction=direction/norm(direction);
local=A(1:3,1:3)\direction(:);local=local/norm(local);
[~,axisXYZ]=max(abs(local));arrayAxis=[2 1 3];dim=arrayAxis(axisXYZ);
order=setdiff(1:3,dim,'stable');order=[order dim];
cache=getappdata(ax,'MovieVoxelTextures');
rgbChanged=isempty(cache)||~isequaln(cache.rgb,volume.Data);
alphaChanged=isempty(cache)||~isequaln(cache.alpha,volume.AlphaData);
axisChanged=isempty(cache)||cache.dim~=dim;
if rgbChanged||axisChanged,data=permute(volume.Data,[order 4]);else,data=cache.data;end
if alphaChanged||axisChanged,alpha=permute(volume.AlphaData,order);else,alpha=cache.alphaPlanes;end
count=size(alpha,3);planes=findobj(ax,'Tag','MovieVoxelPlane');
key=getappdata(ax,'MovieVoxelDimension');
geometryChanged=~isequal(key,dim) || numel(planes)~=count;
if geometryChanged
    delete(planes);planes=gobjects(count,1);
    for k=1:count
        array=zeros(4,3);array(:,dim)=k;
        array(:,order(1))=[.5;sz(order(1))+.5;.5;sz(order(1))+.5];
        array(:,order(2))=[.5;.5;sz(order(2))+.5;sz(order(2))+.5];
        xyz=array(:,[2 1 3]);world=[xyz ones(4,1)]*A';
        planes(k)=surface(ax,reshape(world(:,1),2,2),reshape(world(:,2),2,2),reshape(world(:,3),2,2), ...
            zeros(size(alpha,1),size(alpha,2),3,'single'),'FaceColor','texturemap', ...
            'FaceAlpha','texturemap','AlphaDataMapping','none','EdgeColor','none', ...
            'FaceLighting','none','Tag','MovieVoxelPlane','UserData',k);
    end
    setappdata(ax,'MovieVoxelDimension',dim);
end
% Longer angled paths through a voxel increase attenuation; do not brighten
% or remap functional values to compensate for occlusion.
power=1/max(eps,abs(local(axisXYZ)));
alphaUpdate=geometryChanged||alphaChanged||isempty(cache)||cache.power~=power;
if alphaUpdate,rayAlpha=1-(1-min(1,max(0,alpha))).^power;end
for j=1:numel(planes)
    k=planes(j).UserData;
    if geometryChanged||rgbChanged,planes(j).CData=squeeze(data(:,:,k,:));end
    if alphaUpdate,planes(j).AlphaData=rayAlpha(:,:,k);end
end
setappdata(ax,'MovieVoxelTextures',struct('rgb',volume.Data,'alpha',volume.AlphaData, ...
    'dim',dim,'data',data,'alphaPlanes',alpha,'power',power));
corners=[.5 .5 .5;sz(2)+.5 .5 .5;.5 sz(1)+.5 .5;.5 .5 sz(3)+.5; ...
    sz(2)+.5 sz(1)+.5 .5;sz(2)+.5 .5 sz(3)+.5;.5 sz(1)+.5 sz(3)+.5;sz(2)+.5 sz(1)+.5 sz(3)+.5];
world=[corners ones(8,1)]*A';extent=max(world(:,1:3))-min(world(:,1:3));
radius=norm(extent)/2;spanY=2*radius/double(viewer.CameraZoom)*max(1,viewportSize(2)/viewportSize(1));
distance=norm(double(viewer.CameraPosition-viewer.CameraTarget));
set(ax,'XLim',[min(world(:,1)) max(world(:,1))],'YLim',[min(world(:,2)) max(world(:,2))], ...
    'ZLim',[min(world(:,3)) max(world(:,3))],'DataAspectRatio',[1 1 1], ...
    'Projection','orthographic','CameraPosition',double(viewer.CameraPosition), ...
    'CameraTarget',double(viewer.CameraTarget),'CameraUpVector',double(viewer.CameraUpVector), ...
    'CameraViewAngle',2*atand(spanY/(2*distance)),'Visible','off','SortMethod','depth');
end
