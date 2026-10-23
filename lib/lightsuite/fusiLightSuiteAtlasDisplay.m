function display=fusiLightSuiteAtlasDisplay(texture,nativeMeta,mode,geometry,info)
% Full reference texture in original recording coordinates, including its halo.
shape=double(nativeMeta.nativeSize);
assert(size(texture,3)==shape(3)&&all(isfinite(texture(:))),'Invalid LightSuite atlas display texture.');
if nargin<4,geometry=struct('xData',[1 shape(2)],'yData',[1 shape(1)]);end
if nargin<5,info=struct();end
display=struct('getSlice',@getSlice,'getLabels',@getLabels, ...
    'gridSizeYXZ',shape,'textureSizeYX',size(texture,[1 2]), ...
    'xData',geometry.xData,'yData',geometry.yData,'spacingUm',double(nativeMeta.voxelSizeMm)*1000, ...
    'space','native','atlasMode',mode,'source','Registered full reference; display only');
if isfield(geometry,'uprightVectorXY'),display.uprightVectorXY=geometry.uprightVectorXY;end
if strcmp(mode,'recorded'),display.source='Original acquired anatomy; native coordinates';end
if isfield(geometry,'nativeSize'),display.viewBounds=fusiLightSuiteDisplayBounds(texture,geometry);end
    function plane=getSlice(z)
        plane=texture(:,:,max(1,min(shape(3),round(z))));
        if strcmp(mode,'regions'),plane=fusiRegionLabelRGB(plane,info);end
    end
    function labels=getLabels(z)
        labels=[];if strcmp(mode,'regions'),labels=texture(:,:,max(1,min(shape(3),round(z))));end
    end
end
