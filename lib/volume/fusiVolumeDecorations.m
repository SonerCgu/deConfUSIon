function fusiVolumeDecorations(panel,viewer,ax,S,enabled,lengthUm,legendPanel,displayUnit,showAxes,placement)
% Calibrated screen ruler and camera-following atlas hemisphere labels.
% Viewer3D uses an orthographic frustum fitted to the volume's bounding
% sphere. This matches R2023b's native ScaleBar, with a user-selected length.
if ~isvalid(panel),return;end
if nargin<8,displayUnit='um';end
if nargin<9,showAxes=false;end
if nargin<10,placement='Image bottom right';end
isVolume=~isempty(viewer) && (isstruct(viewer)||isvalid(viewer));
if ~isVolume && (isempty(ax)||~isvalid(ax)),return;end
position=getpixelposition(panel);w=position(3);h=position(4);
if isVolume
    target=viewer.CameraTarget;camera=viewer.CameraPosition;up=viewer.CameraUpVector;
    radius=norm(size(S.underlay).*S.spacing)/2;
    spanY=2*radius/max(eps,viewer.CameraZoom)*max(1,h/max(1,w));
    viewport=[0 0 w h];
else
    target=ax.CameraTarget;camera=ax.CameraPosition;up=ax.CameraUpVector;
    viewport=getpixelposition(ax);w=viewport(3);h=viewport(4);
    spanY=2*norm(camera-target)*tand(ax.CameraViewAngle/2);
end
scale=h/max(eps,spanY);
forward=(target-camera)/max(eps,norm(target-camera));right=cross(forward,up);right=right/max(eps,norm(right));up=cross(right,forward);
extent=[size(S.underlay,2) size(S.underlay,1) size(S.underlay,3)].*S.spacing([2 1 3]);
origin=[.5*S.spacing(2) .5*S.spacing(1) (S.slices(1)-.5)*S.spacing(3)];
corners=origin+[0 0 0;1 0 0;0 1 0;0 0 1;1 1 0;1 0 1;0 1 1;1 1 1].*extent;
projected=viewport(1:2)+[w h]/2+scale*[(corners-target)*right' (corners-target)*up'];
barParent=panel;
holder=findall(barParent,'Tag','FUSIVolumeDecoration','Type','uipanel');
if isempty(holder)
    holder=uipanel(barParent,'Units','pixels','Position',[1 1 260 55],'BorderType','none','BackgroundColor','k', ...
        'AutoResizeChildren','off','Tag','FUSIVolumeDecoration');
    uipanel(holder,'Units','pixels','Position',[1 10 1 3],'BackgroundColor','w','BorderType','none','Tag','VolumeRulerLine');
    uilabel(holder,'Text','','FontColor','w','FontSize',13,'HorizontalAlignment','center', ...
        'Tag','VolumeRulerText','Position',[1 20 100 20]);
end
pixels=lengthUm/1000*scale;
holderWidth=max(160,pixels+30);holderWidth=min(w-10,holderWidth);
centerX=viewport(1)+w/2+scale*dot(mean(corners,1)-target,right);
left=centerX-holderWidth/2;bottom=min(projected(:,2))-40;
if strcmp(placement,'Image bottom right'),left=max(projected(:,1))-holderWidth;bottom=min(projected(:,2))-40;
elseif strcmp(placement,'View bottom right'),left=viewport(1)+w-holderWidth-12;bottom=viewport(2)+8;end
holder.Position=[max(5,min(viewport(1)+w-holderWidth-5,left)) max(5,min(viewport(2)+h-40,bottom)) holderWidth 38];
holder.Visible='off';
if enabled && strcmp(S.units,'mm') && pixels>=2 && pixels<=holderWidth-10
    holder.Visible='on';height=holder.Position(4);
    barLine=findobj(holder,'Tag','VolumeRulerLine');barLine.Position=[(holderWidth-pixels)/2 round(.22*height) pixels 3];
    label=findobj(holder,'Tag','VolumeRulerText');label.Position=[(holderWidth-130)/2 round(.44*height) 130 20];
    if strcmp(displayUnit,'mm'),label.Text=sprintf('%g mm',lengthUm/1000);
    else,label.Text=sprintf('%g %cm',lengthUm,181);end
end
tickLabels=findall(panel,'Tag','VolumeSpatialTick');
if isVolume && showAxes && strcmp(S.units,'mm'),set(tickLabels,'Visible','off');else,delete(tickLabels);end
if isVolume && showAxes && strcmp(S.units,'mm')
    names={'LR / X (mm)','DV / Y (mm)','AP / Z (mm)'};
    if ~isfield(S,'atlasAxisOrder'),names={'X (mm)','Y (mm)','Z (mm)'};end
    for axis=1:3
        start=origin;finish=start;finish(axis)=start(axis)+extent(axis);
        delta=finish-start;
        if scale*norm([dot(delta,right) dot(delta,up)])<40,continue;end
        values=linspace(0,extent(axis),5);
        for tick=1:5
            value=values(tick);
            if value==0 && axis>1,continue;end
            point=start;point(axis)=point(axis)+value;delta=point-target;
            xy=viewport(1:2)+[w h]/2+scale*[dot(delta,right) dot(delta,up)];
            spatialLabel(axis*10+tick,sprintf('%.2g',value),[xy(1)-18 xy(2)-21 40 20]);
        end
        point=(start+finish)/2;delta=point-target;xy=viewport(1:2)+[w h]/2+scale*[dot(delta,right) dot(delta,up)];
        spatialLabel(axis*10+9,names{axis},[xy(1)-40 xy(2)+4 100 20]);
    end
end
% Mark atlas hemisphere in world coordinates, so labels move with rotation.
% Native probe handedness cannot be established from sampling metadata.
labels=findall(panel,'Tag','VolumeHemisphere');
if ~isfield(S,'atlasAxisOrder') && ~isfield(S,'nativeLeftRight')
    delete(labels);return;
end
% Place markers beside the visible anatomy, not at the corners of a padded
% atlas grid. Keep them visible at the viewport edge when zoomed in.
if isfield(S,'atlasBrainMask'),tissue=logical(S.atlasBrainMask);
else,tissue=S.underlayValid & isfinite(S.underlay) & S.underlay>0;end
if isfield(S,'displayLeftRight')&&S.displayLeftRight.flipColumns,tissue=flip(tissue,2);end
cols=find(any(any(tissue,1),3));rows=find(any(any(tissue,2),3));slices=find(any(any(tissue,1),2));
if isempty(cols),cols=[1 size(S.underlay,2)];rows=[1 size(S.underlay,1)];slices=[1 size(S.underlay,3)];end
center=[mean(cols([1 end]))*S.spacing(2) mean(rows([1 end]))*S.spacing(1) (mean(slices([1 end]))+S.slices(1)-1)*S.spacing(3)];
points=repmat(center,2,1);points(:,1)=[cols(1)-.5;cols(end)+.5]*S.spacing(2);
markerXY=viewport(1:2)+[w h]/2+scale*[(points-target)*right' (points-target)*up'];
if norm(diff(markerXY))<75
    % In a sagittal view L/R lie almost on the same screen ray. Separate the
    % text vertically instead of hiding one label behind the other.
    markerXY(:,2)=markerXY(:,2)+[14;-14];
end
names={'Atlas L','Atlas R'};
if isfield(S,'displayLeftRight')
    names={'L','R'};
    if isfield(S,'atlasAxisOrder'),names={'Atlas L','Atlas R'};end
    if strcmp(S.displayLeftRight.columnOneSide,'right'),names=fliplr(names);end
    if ~S.displayLeftRight.confirmed,names=cellfun(@(x)[x '?'],names,'UniformOutput',false);end
elseif ~isfield(S,'atlasAxisOrder')
    names={'L','R'};
    if strcmp(S.nativeLeftRight.columnOneSide,'right'),names=fliplr(names);end
    if ~S.nativeLeftRight.confirmed,names=cellfun(@(x)[x '?'],names,'UniformOutput',false);end
end
for k=1:2
    label=findobj(labels,'UserData',k);
    if isempty(label),label=uilabel(panel,'Text',names{k},'FontColor',[.2 1 1],'FontSize',14, ...
            'FontWeight','bold','Tag','VolumeHemisphere','UserData',k);end
    label.Text=names{k};
    xy=markerXY(k,:);
    % Anchor the entire text outside the appropriate projected hemisphere.
    side=sign(dot(points(k,:)-center,right));if side==0,side=2*k-3;end
    left=xy(1)-32;if side<0,left=xy(1)-70;elseif side>0,left=xy(1)+5;end
    label.HorizontalAlignment='left';if side<0,label.HorizontalAlignment='right';end
    label.Position=[max(0,min(viewport(1)+w-65,left)) max(0,min(viewport(2)+h-22,xy(2)-10)) 65 22];
    label.Visible='on';
end
    function spatialLabel(key,text,position)
        label=findobj(panel,'Tag','VolumeSpatialTick','UserData',key);
        if isempty(label),label=uilabel(panel,'FontColor','w','FontSize',12,'Tag','VolumeSpatialTick','UserData',key);end
        label.Text=text;label.Position=position;label.Visible='on';
    end
end
function value=onOff(tf)
if tf,value='on';else,value='off';end
end
