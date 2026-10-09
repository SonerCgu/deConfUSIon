function fig = fusiVolumeGUI(data)
% Companion native-space viewer for Video GUI matrix/3D recordings.
deConfUSIon_setup();
atlasOnly=isfield(data,'atlasOnly') && data.atlasOnly;
savedAtlasGrid=isfield(data,'transformed') && data.transformed && ...
    isfield(data,'atlasOutputArrayOrder') && strcmp(data.atlasOutputArrayOrder,'DV-LR-AP');
par=data.par; par.scmSizeYXZ=[size(data.PSC,1) size(data.PSC,2) size(data.PSC,3)];
c=scmSpatialCalibration(par);
geo=fusiVolumeGeometry(par,par.scmSizeYXZ);
if ~isfield(data,'inputIsPSC'),data.inputIsPSC=false;end
if ~isfield(data,'transformed'),data.transformed=false;end
sequence=[];localBaselineReset=data.baseline;
if isfield(data.baseline,'localBaseline'),localBaselineReset=data.baseline.localBaseline;end
if ~atlasOnly&&~data.inputIsPSC&&(~data.transformed||isfield(data,'nativePower'))
 power=data.I;if isfield(data,'nativePower'),power=data.nativePower;end
 sequence=fusiScanSequence('init',par,power,data.TR,data.label);data.par.scanSequence=sequence;
 data.nativePower=power;
 if ~isfield(data,'displayDescriptor'),data.displayDescriptor=sequence.scans{sequence.active};end
end
[data.baselineUnderlay,data.baselineInfo]=fusiVolumeBaseline(data);
if isfield(data,'display'),display=data.display;
else
    display=struct('caxis',data.caxis,'colormap',fusiVolumeColormap('blackbdy_iso'), ...
        'colorScheme','blackbdy_iso','signMode',1,'alphaPct',100,'alphaModEnable',true, ...
        'modMinAbs',5,'modMaxAbs',20,'maskThreshold',0,'overlaySmoothSigma',0);
end
lastVideo=display;
spacing=c.spacingUm/1000; units='mm';
if any(~isfinite(spacing) | spacing<=0), spacing=[1 1 1]; units='voxels'; end
if isfield(data,'transformed') && data.transformed
    if isfield(par,'atlasVoxelSizeYXZUm') && numel(par.atlasVoxelSizeYXZUm)==3 && all(isfinite(par.atlasVoxelSizeYXZUm) & par.atlasVoxelSizeYXZUm>0)
        spacing=double(par.atlasVoxelSizeYXZUm(:)')/1000;units='mm';
        c.source='Saved 3D atlas output-grid spacing in row/column/slice order.';
        geo.spacingUm=spacing*1000;geo.source=c.source;geo.fieldOfViewMm=par.scmSizeYXZ.*spacing;
    else
        spacing=[1 1 1]; units='voxels';
        c.source='Transformed grid: enter spacing for the output grid; native spacing was not reused.';
    end
end
nZ=size(data.PSC,3); nOriginal=numel(1:max(1,round(data.interpol)):size(data.PSC,4));
lastMin=(nOriginal-1)*data.TR/60;
screen=get(0,'ScreenSize');w=min(1560,screen(3)-80);h=min(980,screen(4)-110);
fig=uifigure('Name','deConfUSIon | 3D brain / volume','Position',[40 55 w h], ...
    'Color','k','Tag','FUSI_VolumeGUI');
root=uigridlayout(fig,[1 2],'ColumnWidth',{300,'1x',300},'Padding',[12 12 12 12],'BackgroundColor','k');
controls=uipanel(root,'Title','3D vascular volume','FontSize',17,'BackgroundColor','k','ForegroundColor','w');
left=uigridlayout(controls,[3 1],'RowHeight',{'1x',215,70},'Padding',[8 8 8 8],'BackgroundColor','k');
heights=repmat({34},1,34);heights([1 8 13 29 31 34])={55};
g=uigridlayout(left,[34 2],'ColumnWidth',{'1x','1x'}, ...
    'RowHeight',heights,'Scrollable','on','Padding',[6 6 6 6],'RowSpacing',7,'BackgroundColor','k');
exports=uigridlayout(left,[5 2],'RowHeight',{34,34,40,40,40},'ColumnWidth',{'1x','1x'},'Padding',[0 0 0 0],'BackgroundColor','k');
status=uilabel(left,'FontSize',13,'FontColor','w','WordWrap','on','Tag','VolumeStatus');
scene=uipanel(root,'BorderType','none','BackgroundColor','k','Tag','FUSI_VolumeScene');scene.Layout.Column=2;
sg=uigridlayout(scene,[3 2],'RowHeight',{'1x',35,94},'ColumnWidth',{'1x',96},'Padding',[4 4 4 4],'BackgroundColor','k');
renderPanel=uipanel(sg,'BorderType','none','BackgroundColor','k','AutoResizeChildren','off','Tag','VolumeRenderPanel');renderPanel.Layout.Row=1;renderPanel.Layout.Column=1;
timeStamp=uilabel(renderPanel,'Text','','Position',[1 1 230 30],'FontColor','w','BackgroundColor','k', ...
    'HorizontalAlignment','right','FontSize',17,'FontWeight','bold','Tag','VolumeRecordingTime');
legendPanel=uipanel(sg,'BorderType','none','BackgroundColor','k','AutoResizeChildren','off');legendPanel.Layout.Row=1;legendPanel.Layout.Column=2;
legendImage=uiimage(legendPanel,'Position',[6 20 18 200],'ScaleMethod','stretch','ImageSource',zeros(256,12,3,'uint8'));
legendTitle=uilabel(legendPanel,'Text','PSC (%)','FontColor','w','FontSize',14,'WordWrap','on','Tag','VolumeLegend');
legendTicks=gobjects(1,5);
for k=1:5,legendTicks(k)=uilabel(legendPanel,'Text','','FontColor','w','FontSize',14);end
legendPanel.SizeChangedFcn=@(~,~)layoutLegend();
rulerPanel=uipanel(sg,'BorderType','none','BackgroundColor','k');rulerPanel.Layout.Row=2;rulerPanel.Layout.Column=1;
caption=uilabel(sg,'FontSize',13,'FontColor','w','WordWrap','on');caption.Layout.Row=3;caption.Layout.Column=[1 2];
addLabel('Acquired field of view; drag to rotate, scroll to zoom.',1,true);
addLabel('Rendering',2); backend=uidropdown(g,'Items',{'Volume rendering','Surface rendering','Coronal slice stack'},'FontSize',12,'Tag','VolumeBackend'); place(backend,2,2);
addLabel('PSC time selection',3); mode=uidropdown(g,'Items',{'Frame','Interval mean'},'FontSize',12,'Tag','VolumeTimeMode'); place(mode,3,2);
addLabel('Original frame',4); fr=uieditfield(g,'numeric','Value',min(nOriginal,data.frame),'Limits',[1 nOriginal],'RoundFractionalValues','on','FontSize',12,'Tag','VolumeFrame');place(fr,4,2);
addLabel('Mean start (min)',5); start=uieditfield(g,'numeric','Value',0,'Limits',[0 max(eps,lastMin)],'FontSize',12,'Tag','VolumeMeanStart');place(start,5,2);
addLabel('Mean end (min)',6); finish=uieditfield(g,'numeric','Value',lastMin,'Limits',[0 max(eps,lastMin)],'FontSize',12,'Tag','VolumeMeanEnd');place(finish,6,2);
maskBox=uicheckbox(g,'Text','Apply current Video ROI mask','FontSize',12,'Value',data.applyMask,'Tag','VolumeApplyMask');place(maskBox,7,[1 2]);
addLabel('Spacing in array order: row, column, slice. XYZ are local grid axes, not anatomical labels.',8,true);
addLabel('Spacing units',9); unit=uidropdown(g,'Items',{'voxels','mm'},'Value',units,'FontSize',12,'Tag','VolumeUnits');place(unit,9,2);
addLabel('Depth / row spacing (Y)',10); dy=uieditfield(g,'numeric','Value',spacing(1),'Limits',[eps Inf],'FontSize',14);place(dy,10,2);
addLabel('Column spacing (X)',11); dx=uieditfield(g,'numeric','Value',spacing(2),'Limits',[eps Inf],'FontSize',12);place(dx,11,2);
addLabel('Slice spacing (Z)',12); dz=uieditfield(g,'numeric','Value',spacing(3),'Limits',[eps Inf],'FontSize',12);place(dz,12,2);
addLabel(c.source,13,true);
addLabel('Slice range (inclusive)',14); sliceEdit=uieditfield(g,'text','Value',sprintf('1 %d',nZ),'FontSize',12,'Tag','VolumeSliceRange');place(sliceEdit,14,2);
addLabel('Faint Doppler cutoff (%)',15); cutoff=uieditfield(g,'numeric','Value',6,'Limits',[0 100],'FontSize',14,'Tag','VolumeDopplerCutoff');place(cutoff,15,2);
addLabel('Vessel opacity per voxel (%)',16); opacity=uieditfield(g,'numeric','Value',4,'Limits',[0 100],'FontSize',14,'Tag','VolumeDopplerAlpha');place(opacity,16,2);
pscBox=uicheckbox(g,'Text','Show PSC overlay','FontSize',12,'Value',true);place(pscBox,17,1);
signs=uidropdown(g,'Items',{'Positive','Negative','Both signs'},'Value',polarityName(display.signMode),'FontSize',14,'Tag','VolumeSign');place(signs,17,2);
addLabel('Hide PSC below |%|',18); pscCut=uieditfield(g,'numeric','Value',display.maskThreshold,'Limits',[0 Inf],'FontSize',14,'Tag','VolumePSCThreshold');place(pscCut,18,2);
addLabel('PSC color range (%)',19);
rangeEdit=uieditfield(g,'text','Value',sprintf('%.6g %.6g',display.caxis),'FontSize',14,'Tag','VolumeRange');place(rangeEdit,19,2);
addLabel('PSC opacity (%)',20);alpha=uieditfield(g,'numeric','Value',display.alphaPct,'Limits',[0 100],'Tag','VolumeAlpha');place(alpha,20,2);
modulate=uicheckbox(g,'Text','Alpha modulation by |PSC|','Value',display.alphaModEnable,'Tag','VolumeAlphaMod');place(modulate,21,[1 2]);
addLabel('Alpha ramp starts (%)',22);low=uieditfield(g,'numeric','Value',display.modMinAbs,'Tag','VolumeModLow');place(low,22,2);
addLabel('Alpha ramp saturates (%)',23);high=uieditfield(g,'numeric','Value',display.modMaxAbs,'Tag','VolumeModHigh');place(high,23,2);
addLabel('Color scheme',24);color=uidropdown(g,'Items',unique([{display.colorScheme} {'blackbdy_iso','winter_brain_fsl','signed_blackbdy_winter','hot','turbo','jet','gray'}],'stable'),'Value',display.colorScheme,'Tag','VolumeColor');place(color,24,2);
addLabel('Overlay smoothing (px)',25);smooth=uieditfield(g,'numeric','Value',display.overlaySmoothSigma,'Limits',[0 5],'Tag','VolumeSmooth');place(smooth,25,2);
follow=uicheckbox(g,'Text','Follow Video GUI PSC settings','Value',true,'Tag','VolumeFollowVideo');place(follow,26,[1 2]);
autoBg=uicheckbox(g,'Text','Auto vessel opacity and faint cutoff','Value',false,'Tag','VolumeAutoBackground');place(autoBg,27,[1 2]);
addLabel('Doppler reference',28);items={'Video underlay'};if data.baselineInfo.available,items={'Baseline Doppler','Video underlay'};end
if isfield(data,'underlayProcessed') && data.underlayProcessed,items=[{'Video underlay'} setdiff(items,{'Video underlay'},'stable')];end
reference=uidropdown(g,'Items',items,'Tag','VolumeReference');place(reference,28,2);
addLabel(sprintf('PSC uses the Video GUI baseline: %.4g-%.4g seconds. Its normalization is carried over.',baselineLimits(data)),29,true);
reset=uibutton(g,'Text','Reset view','FontSize',14,'BackgroundColor',[.12 .45 .23],'FontColor','w','ButtonPushedFcn',@resetCamera);place(reset,30,1);
help=uibutton(g,'Text','Spacing / help','FontSize',14,'BackgroundColor',[.12 .45 .23],'FontColor','w','ButtonPushedFcn',@showDetails);place(help,30,2);
addLabel('A vascular volume depicts vessels within the scan. A whole-brain tissue outline needs anatomy or a reviewed brain mask.',31,true);
png=uibutton(exports,'Text','Export image (PNG)','Tag','VolumeExportPNG','FontSize',14,'BackgroundColor',[.48 .31 .08],'FontColor','w','ButtonPushedFcn',@(~,~)exportView('png'));
mp4=uibutton(exports,'Text','Export rotation (MP4)','Tag','VolumeExportMP4','FontSize',14,'BackgroundColor',[.48 .31 .08],'FontColor','w','ButtonPushedFcn',@(~,~)exportView('mp4'));
play=uibutton(exports,'Text','Play time series','FontSize',14,'BackgroundColor',[.12 .45 .23],'FontColor','w','Tag','VolumePlay','ButtonPushedFcn',@togglePlayback);
initialFPS=5;if isfield(data,'fps'),initialFPS=min(30,max(.2,data.fps));end
fps=uieditfield(exports,'numeric','Value',initialFPS,'Limits',[.2 60],'FontSize',14,'Tag','VolumeFPS','ValueDisplayFormat','%g fps','Tooltip','Requested playback / time-series export rate. Live playback follows this clock and may skip display frames if rendering falls behind; exports include every selected acquired frame.','ValueChangedFcn',@fpsChanged);
timeMovie=uibutton(exports,'Text','Export time series (MP4)','FontSize',14,'BackgroundColor',[.48 .31 .08],'FontColor','w','Tag','VolumeTimeMovie','ButtonPushedFcn',@(~,~)exportView('time'));
place(play,1,1);place(fps,1,2);
reset.Parent=exports;place(reset,2,1);help.Parent=exports;place(help,2,2);place(png,3,[1 2]);place(timeMovie,4,[1 2]);place(mp4,5,[1 2]);
timeMovie.Visible='off';
movieKind=uidropdown(exports,'Items',{'PSC time series','Camera rotation','PSC time series + rotation'},'Tag','VolumeMovieKind', ...
    'Tooltip','Choose acquired PSC, camera rotation, or both simultaneously.','ValueChangedFcn',@stopPlayback);
place(movieKind,4,[1 2]);mp4.Text='Export movie (MP4)';mp4.ButtonPushedFcn=@exportSelectedMovie;
% Keep the inherited PSC controls near the top; geometry stays accessible in
% the scroll area and through the permanently visible Spacing / help button.
rows=[1 2 5 6 7 8 23 25 26 27 28 29 30 24 22 21 9 17 11 12 13 14 15 10 16 3 20 4 18 31 32];
children=g.Children;
for k=1:numel(children),r=children(k).Layout.Row;if isscalar(r)&&r<=numel(rows),children(k).Layout.Row=rows(r);end;end
heights=repmat({34},1,34);heights([1 18 25 30 32])={55};g.RowHeight=heights;
mode.ValueChangedFcn=@(~,~)timeFields();timeFields();
renderer=[]; vol=[]; surfaceAx=[]; initialCamera=[]; currentBackend=''; geometry=[];
cachedOpt=[];cachedSnapshot=[];nativeFrame=[];stackKey=[];stackObjects=[];stackBackObjects=[];stackSideObjects=[];stackDataKey=[];stackDataRows=[];dragPoint=[];anatomyKey=[];nativeAnatomy=[];autoProfile=[];surfaceKey=[];lastLegend=[];decorListeners=[];busy=false;pending=false;playTimer=[];playing=false;atlasContext=[];
stackFitPoints=[];stackLayoutKey=[];markerPoint=[.08 .12];placingMarker=false;
nativeSideExplicit=isfield(par,'nativeColumnOneSide');
playClock=[];playFrames=[];playIndex=1;playRate=initialFPS;rgbaBackground=[];rgbaBackgroundKey=[];
atlasFile='';currentAtlasTransform=[];nativeDisplayGeometry=struct('spacing',spacing,'units',units);
voxelMask=[];voxelMesh=[];voxelIndices=[];voxelPatch=[];
g.RowHeight=[g.RowHeight {34 34 34 55 34 34 34 34 34}];
loadAtlas=uibutton(g,'Text','Load atlas transform','BackgroundColor',[.12 .45 .23],'FontColor','w','Tag','VolumeLoadAtlas','ButtonPushedFcn',@loadAtlasContext);place(loadAtlas,35,1);
clearAtlas=uibutton(g,'Text','Native view','BackgroundColor',[.12 .45 .23],'FontColor','w','ButtonPushedFcn',@clearAtlasContext);place(clearAtlas,35,2);
adjustAtlas=uibutton(g,'Text','Register / adjust atlas','BackgroundColor',[.12 .45 .23],'FontColor','w','Tag','VolumeAdjustAtlas','ButtonPushedFcn',@adjustAtlasContext);place(adjustAtlas,36,[1 2]);
reviewAtlas=uibutton(g,'Text','Review all three planes','BackgroundColor',[.12 .45 .23],'FontColor','w','Tag','VolumeReviewAtlas','ButtonPushedFcn',@reviewAtlasContext);place(reviewAtlas,37,1);
atlasType=uidropdown(g,'Items',{'Histology','Vascular'},'Tag','VolumeAtlasType','ValueChangedFcn',@changed);place(atlasType,37,2);
atlasNote=uilabel(g,'Text','Load a reviewed 3D transform to add whole-brain atlas context.','FontColor','w','WordWrap','on');place(atlasNote,38,[1 2]);
atlasPreview=uibutton(g,'Text','Open complete Allen brain','BackgroundColor',[.12 .45 .23],'FontColor','w','Tag','VolumeAtlasOnly','ButtonPushedFcn',@(~,~)fusiAtlasVolumeGUI());place(atlasPreview,39,[1 2]);
help.Parent=g;place(help,30,2);atlasPreview.Parent=exports;atlasPreview.Text='Allen brain atlas';place(atlasPreview,2,2);
addLabel('Atlas opacity per voxel (%)',40);atlasAlpha=uieditfield(g,'numeric','Value',80,'Limits',[0 100],'Tag','VolumeAtlasAlpha','ValueChangedFcn',@changed);place(atlasAlpha,40,2);
addLabel('3D PSC strength',44);strength=uieditfield(g,'numeric','Value',5,'Limits',[.25 20], ...
    'Tag','VolumePSCStrength','Tooltip','Display-only opacity multiplier, initially 5 and adjustable up to 20. PSC values and colors stay unchanged.', ...
    'ValueChangedFcn',@changed);place(strength,44,2);
addLabel('Native column 1 side',45);nativeLR=uidropdown(g,'Items',{'Left','Right'},'Value','Left','Tag','VolumeNativeLR', ...
    'Tooltip','Choose anatomical side of column 1 using your acquisition orientation.','ValueChangedFcn',@changed);place(nativeLR,45,2);
nativeConfirmed=uicheckbox(g,'Text','L/R confirmed from acquisition','Value',true,'Tag','VolumeNativeLRConfirmed','ValueChangedFcn',@changed);place(nativeConfirmed,46,[1 2]);
displayLR=uidropdown(g,'Items',{'As acquired','Left on image left','Right on image left'},'Value','As acquired', ...
    'Tag','VolumeDisplayLR','Tooltip','Display convention only. As acquired keeps the native column-one side after loading an atlas transform. No quantitative samples or saved transform are changed.','ValueChangedFcn',@changed);
lrMarker=uidropdown(g,'Items',{'Automatic','Custom position','Hidden'},'Value','Automatic', ...
    'Tag','VolumeLRMarker','Tooltip','Custom position: use marker X/Y, or click in a surface/stack image. This moves labels only.','ValueChangedFcn',@markerChanged);
markerX=uieditfield(g,'numeric','Value',8,'Limits',[0 100],'Tag','VolumeLRMarkerX','ValueChangedFcn',@markerPositionChanged);
markerY=uieditfield(g,'numeric','Value',12,'Limits',[0 100],'Tag','VolumeLRMarkerY','ValueChangedFcn',@markerPositionChanged);
if isfield(par,'nativeColumnOneSide') && ismember(lower(par.nativeColumnOneSide),{'left','right'})
    nativeLR.Value=[upper(par.nativeColumnOneSide(1)) lower(par.nativeColumnOneSide(2:end))];nativeConfirmed.Value=true;
elseif savedAtlasGrid && isfield(data,'atlasOutputGeometry') && isstruct(data.atlasOutputGeometry) && ...
        isfield(data.atlasOutputGeometry,'nativeColumnOneSide')
    side=lower(data.atlasOutputGeometry.nativeColumnOneSide);
    if ismember(side,{'left','right'}),nativeLR.Value=[upper(side(1)) side(2:end)];end
end
clearPSC=uicheckbox(g,'Text','Strong PSC opacity (Video colors unchanged)','Value',true,'Tag','VolumeClearPSC','ValueChangedFcn',@changed);place(clearPSC,48,[1 2]);
vessels=uicheckbox(g,'Text','Show grayscale Doppler vessels','Value',true,'Tag','VolumeShowDoppler','ValueChangedFcn',@changed);place(vessels,49,[1 2]);
addLabel('Vessel display gamma',50);vesselGamma=uieditfield(g,'numeric','Value',1,'Limits',[.2 3], ...
    'Tag','VolumeVesselGamma','Tooltip','Display brightness only; below 1 reveals weaker vessels. PSC values and colors are unchanged.','ValueChangedFcn',@changed);place(vesselGamma,50,2);
addLabel('Vessel contrast gain',51);vesselGain=uieditfield(g,'numeric','Value',2,'Limits',[.5 5],'Tag','VolumeVesselGain','ValueChangedFcn',@changed);place(vesselGain,51,2);
pscOnly=uibutton(g,'Text','PSC only / verify functional colors','BackgroundColor',[.12 .45 .23],'FontColor','w', ...
    'Tag','VolumePSCOnly','ButtonPushedFcn',@showPSCOnly);place(pscOnly,52,[1 2]);
addLabel('Doppler contrast preset',47);
initialUnderlayPreset='Mask Editor standard';
if isfield(data,'underlayProcessed') && data.underlayProcessed,initialUnderlayPreset='Video / saved Mask Editor';end
underPreset=uidropdown(g,'Items',{'Video / saved Mask Editor','Mask Editor standard'}, ...
    'Value',initialUnderlayPreset,'Tag','VolumeUnderlayPreset','ValueChangedFcn',@changed);
place(underPreset,47,2);
if atlasOnly
    controls.Title='Complete Allen brain atlas';fig.Name='deConfUSIon | Complete Allen brain atlas';
    pscBox.Value=false;pscBox.Enable='off';play.Enable='off';timeMovie.Enable='off';
    mode.Enable='off';fr.Enable='off';start.Enable='off';finish.Enable='off';
    maskBox.Enable='off';sliceEdit.Enable='off';follow.Value=false;follow.Enable='off';
    loadAtlas.Enable='off';clearAtlas.Enable='off';adjustAtlas.Enable='off';atlasPreview.Enable='off';
    atlasAlpha.Value=80;atlasNote.Text='Complete atlas anatomy. No animal recording or functional response is displayed.';
    children=g.Children;
    for k=1:numel(children),children(k).Visible='off';children(k).Layout.Row=1;children(k).Layout.Column=1;end
    addLabel('Complete reference brain; drag to rotate, scroll to zoom.',1,true);
    addLabel('Rendering',2);backend.Visible='on';place(backend,2,2);
    addLabel('Atlas reference',3);atlasType.Visible='on';place(atlasType,3,2);
    addLabel('Atlas opacity per voxel (%)',4);atlasAlpha.Visible='on';place(atlasAlpha,4,2);
    reviewAtlas.Visible='on';place(reviewAtlas,5,[1 2]);
    addLabel('Atlas sampling, DV / LR / AP (mm)',6,true);
    for k=1:3
        h={dy,dx,dz};h{k}.Visible='on';place(h{k},6+k,2);
        names={'Depth / DV','Left-right / LR','Anterior-posterior / AP'};addLabel(names{k},6+k);
    end
    atlasNote.Visible='on';place(atlasNote,10,[1 2]);
    g.RowHeight={55,34,34,34,40,45,34,34,34,70};
    play.Visible='off';fps.Visible='off';timeMovie.Visible='off';exports.RowHeight={0,34,40,0,40};left.RowHeight={'1x',128,70};
    atlasPreview.Enable='on';atlasPreview.Text='Spacing / help';atlasPreview.ButtonPushedFcn=@showDetails;
end
% Physical ruler and view presets stay available for both rendering backends.
viewChoice=uidropdown(g,'Items',{'Oblique','Dorsal','Coronal','Sagittal','Dorsal oblique','Sagittal oblique','Coronal oblique'},'Value','Coronal','Tag','VolumeViewPreset', ...
    'Tooltip','Align the display camera to the grid. Atlas views use DV/LR/AP; this does not register the scan.', 'ValueChangedFcn',@alignCamera);
place(viewChoice,41,2);addLabel('Align brain view',41);
rulerBox=uicheckbox(g,'Text','Show physical scale bar','Value',true,'Tag','VolumeScaleBar','ValueChangedFcn',@changed);place(rulerBox,42,[1 2]);
rulerLength=uidropdown(g,'Items',{'50','100','250','500','1000','2000','5000'},'Editable','on','Value','500','Tag','VolumeScaleLength', ...
    'Tooltip','Scale-bar length in micrometres. Available only with calibrated millimetre spacing.','ValueChangedFcn',@changed);
place(rulerLength,43,2);addLabel('Scale bar length (um)',43);
microUnit=[char(181) 'm'];rulerUnit=uidropdown(g,'Items',{microUnit,'mm'},'Value',microUnit,'Tag','VolumeRulerUnit','ValueChangedFcn',@rulerUnitChanged);lastRulerUnit=microUnit;
rulerPosition=uidropdown(g,'Items',{'Image bottom right','Below image','View bottom right'},'Value','Image bottom right','Tag','VolumeRulerPosition','ValueChangedFcn',@changed);
axesBox=uicheckbox(g,'Text','Show spatial axes (mm)','Value',false,'Tag','VolumeSpatialAxes','ValueChangedFcn',@changed);
movieResolution=uidropdown(g,'Items',{'Fast (720 px)','HD (1080 px)','Full HD (1920 px)','Display size'},'Value','HD (1080 px)', ...
    'Tag','VolumeMovieResolution','Tooltip','Longest movie image edge in pixels. This changes output resolution only, not the acquired data or selected frames.');
voxelPSC=uicheckbox(g,'Text','Unsmoothed voxel PSC surface','Value',true,'Tag','VolumeVoxelPSC','ValueChangedFcn',@changed);
if atlasOnly
    g.RowHeight={55,34,34,34,40,45,34,34,34,70,34,34,34};place(viewChoice,11,2);addLabel('Align brain view',11);
    place(rulerBox,12,[1 2]);place(rulerLength,13,2);addLabel('Scale bar length (um)',13);
else
    % Make native vessel controls directly accessible above the time/PSC
    % controls, rather than requiring a trip through the geometry section.
    order=[1 2 3 4 8 9 10 11 12 13 14 15 17 18 19 20 21 23 44 5 6 7 22 24 34 35 36 37 38 39 45 43 44 45 25 26 27 28 45 29 30 40 41 16 31 32];
    children=g.Children;
    for k=1:numel(children)
        row=children(k).Layout.Row;if isscalar(row)&&row<=numel(order),children(k).Layout.Row=order(row);end
    end
    place(underPreset,46,2);
    presetLabel=findobj(g,'Type','uilabel','Text','Doppler contrast preset');place(presetLabel,46,1);
    place(help,42,[1 2]);place(clearPSC,47,[1 2]);
    place(vessels,48,[1 2]);place(vesselGamma,49,2);place(vesselGain,50,2);place(pscOnly,51,[1 2]);
    place(findobj(g,'Type','uilabel','Text','Vessel display gamma'),49,1);
    place(findobj(g,'Type','uilabel','Text','Vessel contrast gain'),50,1);
    heights=repmat({34},1,51);heights([1 23 28 34 39 43])={55};g.RowHeight=heights;
end
excluded=uieditfield(g,'text','Value','','Tag','VolumeExcludeSlices','Tooltip','Space-separated original source slices to exclude. Exclusions affect PSC and vessels, never the complete atlas reference.','ValueChangedFcn',@changed);
stackTiles=uieditfield(g,'numeric','Value',6,'Limits',[1 30],'RoundFractionalValues','on','Tag','VolumeStackTiles','ValueChangedFcn',@changed);
stackCols=uieditfield(g,'numeric','Value',6,'Limits',[1 10],'RoundFractionalValues','on','Tag','VolumeStackColumns','ValueChangedFcn',@changed);
slabWidth=uieditfield(g,'numeric','Value',250,'Limits',[1 Inf],'Tag','VolumeSlabWidth','ValueChangedFcn',@changed);
slabMode=uidropdown(g,'Items',{'Slice count','Physical width'},'Value','Slice count','Tag','VolumeSlabMode','ValueChangedFcn',@stackChanged);
slabCount=uieditfield(g,'numeric','Value',5,'Limits',[1 264],'RoundFractionalValues','on','Tag','VolumeSlabCount','ValueChangedFcn',@stackChanged);
slabDepthGain=uieditfield(g,'numeric','Value',3,'Limits',[1 10],'Tag','VolumeSlabDepthGain','Tooltip','Exaggerate slab depth for display only. Use 1 for physical thickness. PSC averages and in-plane scale bars are unchanged.','ValueChangedFcn',@stackChanged);
stackGap=uieditfield(g,'numeric','Value',15,'Limits',[0 100],'Tag','VolumeStackGap','Tooltip','Empty gap between adjacent slice tiles, as a percentage of the slice width. Display layout only.','ValueChangedFcn',@stackChanged);
stackStagger=uieditfield(g,'numeric','Value',20,'Limits',[0 150],'Tag','VolumeStackStagger','Tooltip','Rise between successive tiles, as a percentage of slice height. Zero gives a straight strip. Display layout only.','ValueChangedFcn',@stackChanged);
stackView=uidropdown(g,'Items',{'Paper oblique','Shallow oblique','Face-on','Custom'},'Value','Paper oblique','Tag','VolumeStackView','ValueChangedFcn',@stackViewChanged);
stackYaw=uieditfield(g,'numeric','Value',-6,'Limits',[-180 180],'Tag','VolumeStackYaw','ValueChangedFcn',@stackAnglesChanged);
stackTilt=uieditfield(g,'numeric','Value',8,'Limits',[-85 85],'Tag','VolumeStackTilt','ValueChangedFcn',@stackAnglesChanged);
stackRoll=uieditfield(g,'numeric','Value',0,'Limits',[-180 180],'Tag','VolumeStackRoll','ValueChangedFcn',@stackAnglesChanged);
stackAutoLayout=uicheckbox(g,'Text','Arrange larger stacks in rows','Value',true,'Tag','VolumeStackAutoLayout','ValueChangedFcn',@stackChanged);
stackAutoFit=uicheckbox(g,'Text','Fit when tile count changes','Value',true,'Tag','VolumeStackAutoFit','Tooltip','Retain your rotation and relative zoom while fitting a changed number of tiles. Slab-width edits keep the camera unchanged.','ValueChangedFcn',@stackChanged);
stackFit=uibutton(g,'Text','Fit stack to image','Tag','VolumeStackFit','BackgroundColor',[.12 .45 .23],'FontColor','w','ButtonPushedFcn',@fitStack);
stackRange=uieditfield(g,'text','Value','','Tag','VolumeStackRange','Tooltip','Optional first/last slab center in current atlas AP or native source slice indices. Blank fits all brain slices.','ValueChangedFcn',@changed);
stackTimes=uieditfield(g,'text','Value','','Tag','VolumeStackTimes','Tooltip','Optional recording times in minutes, e.g. 0 2 5 10. Each time repeats the same coronal slabs in a new row. Nearest acquired frames are shown, with their actual times. Blank follows the current frame or interval.','ValueChangedFcn',@stackChanged);
stackLabels=uicheckbox(g,'Text','Show slice ranges on tiles','Value',false,'Tag','VolumeStackLabels','ValueChangedFcn',@stackChanged);
stackNote=uilabel(g,'Text','Choose Coronal slice stack under Rendering. Slabs average finite PSC samples. Full-resolution atlas sampling is used: 250 um = 5 samples on a 50 um atlas. This does not increase ultrasound resolution.','FontColor','w','WordWrap','on','Tag','VolumeStackNote');
scanButton=uibutton(g,'Text','Scans / order (up to 10)','Tag','VolumeScanSequence','BackgroundColor',[.32 .24 .46],'FontColor','w','ButtonPushedFcn',@manageVolumeSequence);
scanChoice=uidropdown(g,'Items',{data.label},'Tag','VolumeOverlayScan','ValueChangedFcn',@selectVolumeScan);
baselineButton=uibutton(g,'Text','Baseline source / window','Tag','VolumeBaselineSource','BackgroundColor',[.32 .24 .46],'FontColor','w','ButtonPushedFcn',@changeVolumeBaseline);
baselineReset=uibutton(g,'Text','Reset local baseline','Tag','VolumeResetBaseline','BackgroundColor',[.12 .39 .28],'FontColor','w','ButtonPushedFcn',@resetVolumeBaseline);
normalise=uicheckbox(g,'Text','Use each scan own baseline','Tag','VolumeNormalizeScans','ValueChangedFcn',@normaliseVolumeScans);
sequenceMovie=uicheckbox(g,'Text','Play included scans in order','Tag','VolumeSequenceMovie','ValueChangedFcn',@sequenceScopeChanged, ...
 'Tooltip','Play/export every acquired frame of each ticked scan, in the chosen order. Start/end below applies to current-scan playback.');
baselineNote=uilabel(g,'Text','','WordWrap','on','FontColor','w','Tag','VolumeBaselineNote');
motionPath=uidropdown(g,'Items',{'Orbit around current view','Gentle yaw','Gentle tilt','Oblique orbit','Fixed camera'}, ...
 'Value','Gentle yaw','Tag','VolumeMotionPath','ValueChangedFcn',@stopPlayback);
motionSpeed=uieditfield(g,'numeric','Value',10,'Limits',[.1 120],'Tag','VolumeMotionSpeed','ValueChangedFcn',@stopPlayback);
motionAmplitude=uieditfield(g,'numeric','Value',20,'Limits',[1 80],'Tag','VolumeMotionAmplitude','ValueChangedFcn',@stopPlayback);
rotationDuration=uieditfield(g,'numeric','Value',12,'Limits',[1 600],'Tag','VolumeRotationDuration');
C=struct();names={'backend','mode','fr','start','finish','sliceEdit','excluded','maskBox','follow','pscBox','signs','color','rangeEdit','alpha','strength','clearPSC','modulate','low','high','smooth','pscCut','pscOnly','vessels','reference','underPreset','vesselGamma','vesselGain','opacity','cutoff','autoBg','loadAtlas','clearAtlas','adjustAtlas','reviewAtlas','atlasType','atlasAlpha','atlasNote','viewChoice','nativeLR','nativeConfirmed','rulerBox','rulerLength','help','stackTiles','stackCols','slabWidth','stackRange','stackNote','unit','dy','dx','dz'};
names=[names {'rulerUnit','rulerPosition','axesBox','movieResolution','voxelPSC','slabMode','slabCount','slabDepthGain','stackTimes','stackLabels','stackGap','stackStagger','stackView','stackYaw','stackTilt','stackRoll','displayLR','lrMarker','markerX','markerY','stackAutoLayout','stackAutoFit','stackFit'}];
names=[names {'scanButton','scanChoice','baselineButton','baselineReset','normalise','sequenceMovie','baselineNote','motionPath','motionSpeed','motionAmplitude','rotationDuration'}];
for k=1:numel(names),C.(names{k})=eval(names{k});end
fusiVolumeControlsLayout(fig,left,root,g,C,atlasOnly);
for h={stackTiles stackCols slabWidth stackRange},h{1}.ValueChangedFcn=@stackChanged;end
stackTabs=findobj(fig,'Tag','VolumeAtlasTabs');stackTabs.SelectionChangedFcn=@stackTabSelected;
if atlasOnly,movieKind.Items={'Camera rotation'};movieKind.Value='Camera rotation';end
left.RowHeight={'1x',215,70};
if atlasOnly,left.RowHeight={'1x',128,70};end
controlsToUpdate={backend,mode,fr,start,finish,maskBox,unit,dy,dx,dz,sliceEdit,cutoff,opacity,pscBox,signs,pscCut,rangeEdit,alpha,modulate,low,high,color,smooth,autoBg,reference};
for k=1:numel(controlsToUpdate),controlsToUpdate{k}.ValueChangedFcn=@changed;end
follow.ValueChangedFcn=@followChanged;
setappdata(fig,'FUSIVolumeSync',@syncVideo);setappdata(fig,'FUSIVolumeRefresh',@refresh);
setappdata(fig,'FUSIVolumeLoadAtlas',@installAtlasContext);
movieRendering=false;
playMotionOffset=0;
sequencePlan=[];playShownFrame=0;playCamera=[];
setappdata(fig,'FUSIVolumePlayback',struct('get',@playbackInfo,'setFrame',@setFrame,'exportFrame',@setExportFrame,'restore',@restorePlayback,'stop',@stopPlayback,'isPlaying',@playbackActive));
setappdata(fig,'FUSIGetScanSequence',@getVolumeSequence);setappdata(fig,'FUSIVolumeData',@getVolumeData);
setappdata(fig,'FUSIVolumeMotion',@motionSettings);
setappdata(fig,'FUSIVolumeWaitRender',@waitRender);
setappdata(fig,'FUSIVolumeCameraMoved',@cameraMoved);
setappdata(fig,'FUSIVolumeExportProgress',@exportProgress);
setappdata(fig,'FUSIVolumeUpdateDecorations',@updateDecorations);
fig.DeleteFcn=@cleanupPlayback;
theme(fig);
backend.Tooltip='Rendering: Volume shows translucent 3D data; Surface shows threshold contours; Coronal slice stack exposes interior PSC on slabs. Left-drag surfaces/stacks to rotate; scroll to zoom.';
opacity.Tooltip='Editing disables automatic balance. Opacity per voxel along a 3D ray; high values can obscure deep PSC. Start at 2-10%.';
autoBg.Tooltip='Choose both settings deterministically from baseline anatomy, fixed across movie frames. Only the Doppler background is hidden; valid PSC follows Video settings.';
cutoff.Tooltip='Percentage of normalized linear Doppler power. Higher hides faint signal. Editing switches to manual balance.';
low.Tooltip='The absolute PSC at which the opacity ramp starts, using exactly the Video GUI formula.';
high.Tooltip='The absolute PSC at which the opacity ramp saturates at the selected PSC opacity.';
if exist('viewer3d','file')~=2 || exist('volshow','file')~=2, backend.Value='Surface rendering'; end
drawnow nocallbacks; % Finish the grid layout before allocating the 3D viewport.
refreshSequenceWidgets();refresh();alignCamera([],[]);

    function h=addLabel(text,row,wide)
        if nargin<3,wide=false;end
        h=uilabel(g,'Text',text,'FontSize',12,'WordWrap','on');
        if wide,place(h,row,[1 2]);else,place(h,row,1);end
    end
    function place(h,row,col)
        h.Layout.Row=row;h.Layout.Column=col;
    end
    function refreshSequenceWidgets()
        enabled=~isempty(sequence)&&~atlasOnly&&~data.inputIsPSC;
        for h={scanButton baselineButton baselineReset normalise sequenceMovie},h{1}.Enable=onOff(enabled);end
        scanChoice.Enable='off';
        if enabled
            labels=fusiScanSequence('labels',sequence);scanChoice.Items=labels;scanChoice.ItemsData=1:numel(labels);scanChoice.Value=sequence.active;
            scanChoice.Tooltip=labels{sequence.active};
            scanChoice.Enable=onOff(numel(labels)>1);normalise.Value=strcmp(sequence.normMode,'local');
        end
        baselineNote.Text=sprintf('%s | %.4g-%.4g s\nPSC = 100*(power - baseline mean)/baseline mean, for each voxel. Own-baseline mode uses the chosen seconds independently within every scan; no maximum scaling.',fusiBaselineReference('label',data.baseline),baselineLimits(data));
        if sequenceMovie.Value,start.Enable='off';finish.Enable='off';else,start.Enable='on';finish.Enable='on';end
        if atlasOnly,start.Enable='off';finish.Enable='off';end
    end
    function q=getVolumeSequence(),q=sequence;end
    function d=getVolumeData(),d=data;end
    function manageVolumeSequence(~,~)
        stopPlayback();
        try
            if isappdata(fig,'FUSIScanSequenceRequest'),q=getappdata(fig,'FUSIScanSequenceRequest');rmappdata(fig,'FUSIScanSequenceRequest');
            else,q=sequence;q.atlasRegistered=~isempty(atlasContext)||data.transformed;q=fusiScanSequenceDialog(q,data.baseline,fusiBaselineRawStart(data.par,pwd));end
            if isempty(q),return;end
            assert(numel(q.scans)<=fusiScanSequence('maxScans'),'deConfUSIon:ScanSequenceCount','Choose up to ten scans.');
            q.originalKey=sequence.originalKey;
            assert(any(cellfun(@(d)strcmp(d.key,q.originalKey),q.scans)), ...
                'deConfUSIon:OriginalScan','Keep the originally loaded dataset; untick it to exclude it from playback.');
            setVolumeScan(q,q.active,true);sequencePlan=[];
        catch ME,sequenceError(ME);end
    end
    function selectVolumeScan(~,~)
        stopPlayback();try,setVolumeScan(sequence,scanChoice.Value,true);catch ME,sequenceError(ME);end
    end
    function normaliseVolumeScans(~,~)
        stopPlayback();q=fusiScanSequence('reference',sequence,data.baseline);
        q.normMode='shared';if normalise.Value,q.normMode='local';end
        try,setVolumeScan(q,q.active,true);sequencePlan=[];catch ME,sequenceError(ME);end
    end
    function changeVolumeBaseline(~,~)
        stopPlayback();
        try
            b=data.baseline;
            if isappdata(fig,'FUSIBaselineRequest'),b=getappdata(fig,'FUSIBaselineRequest');rmappdata(fig,'FUSIBaselineRequest');
            else
                context=data.par;context.scmSizeYXZ=sequence.scans{sequence.active}.spatialSize;
                b=fusiBaselineSourceDialog(b,data.TR,context.scmSizeYXZ,fusiBaselineRawStart(context,pwd),context);
            end
            if isempty(b),return;end
            if ~fusiBaselineReference('isExternal',data.baseline)&&fusiBaselineReference('isExternal',b),localBaselineReset=data.baseline;end
            q=sequence;candidate=data;candidate.baseline=b;
            if fusiBaselineReference('isExternal',b),q.normMode='shared';q.sharedReference=b.reference;
            else,q.localWindowSec=[b.start b.end];q.sharedReference=[];end
            old=data;data=candidate;
            try,setVolumeScan(q,q.active,true);catch ME,data=old;rethrow(ME);end
            sequencePlan=[];
        catch ME,sequenceError(ME);end
    end
    function resetVolumeBaseline(~,~)
        b=localBaselineReset;if isfield(b,'reference'),b=rmfield(b,'reference');end
        setappdata(fig,'FUSIBaselineRequest',b);changeVolumeBaseline([],[]);
    end
    function sequenceScopeChanged(~,~)
        stopPlayback();sequencePlan=[];refreshSequenceWidgets();
    end
    function sequenceError(ME)
        setappdata(fig,'FUSIScanSequenceError',ME.message);status.Text=ME.message;refreshSequenceWidgets();
    end
    function setVolumeScan(q,index,showProgress,deferRefresh)
        if nargin<4,deferRefresh=false;end
        pg=[];
        if showProgress,pg=fusiBaselineProgress('open','Preparing 3D scan / baseline');end
        guard=onCleanup(@()fusiBaselineProgress('close',pg)); %#ok<NASGU>
        report=@(fraction,message)volumeScanProgress(pg,fraction,message);
        maskFile='';modeUnderlay='keep';if isfield(q,'underlayMode'),modeUnderlay=q.underlayMode;end
        if data.transformed&&fusiScanSequence('shareAtlas',q),modeUnderlay='keep';end
        if strcmp(modeUnderlay,'mask')
            if isfield(q.scans{index},'maskFile')&&isfile(q.scans{index}.maskFile),maskFile=q.scans{index}.maskFile;
            elseif isappdata(fig,'FUSIOverlayUnderlayRequest'),maskFile=getappdata(fig,'FUSIOverlayUnderlayRequest');rmappdata(fig,'FUSIOverlayUnderlayRequest');
            else
                paths=fusiResolveAnalysisFolder(q.scans{index}.rawFile);
                [name,folder]=uigetfile('*.mat','Choose scan Mask Editor underlay',paths.datasetFolder);
                if isequal(name,0),error('deConfUSIon:ProcessingCancelled','Scan selection cancelled.');end
                maskFile=fullfile(folder,name);
            end
        end
        [candidate,q]=fusiVolumeSequenceData(data,q,index,report,maskFile);
        if ~isempty(maskFile),q.scans{index}.maskFile=maskFile;candidate.par.scanSequence=q;end
        data=candidate;sequence=q;par=data.par;
        nOriginal=size(data.PSC,4);lastMin=(nOriginal-1)*data.TR/60;
        fr.Value=1;fr.Limits=[1 nOriginal];start.Value=min(start.Value,lastMin);
        finish.Limits=[0 max([eps lastMin finish.Limits(2)])];finish.Value=lastMin;
        start.Limits=[0 max(eps,lastMin)];finish.Limits=[0 max(eps,lastMin)];
        cachedOpt=[];cachedSnapshot=[];nativeFrame=[];anatomyKey=[];nativeAnatomy=[];
        rgbaBackground=[];rgbaBackgroundKey=[];surfaceKey=[];stackDataKey=[];stackDataRows=[];
        oldReference=reference.Value;reference.Items={'Video underlay'};
        if data.baselineInfo.available,reference.Items={'Baseline Doppler','Video underlay'};end
        if strcmp(modeUnderlay,'keep'),reference.Value='Video underlay';
        elseif ismember(oldReference,reference.Items),reference.Value=oldReference;end
        if isfield(data,'underlayProcessed')&&data.underlayProcessed,underPreset.Value='Video / saved Mask Editor';end
        refreshSequenceWidgets();
        if ~deferRefresh
            refresh();if isappdata(fig,'FUSIVolumeLastError'),throw(getappdata(fig,'FUSIVolumeLastError'));end
        end
        if isappdata(fig,'FUSIScanSequenceError'),rmappdata(fig,'FUSIScanSequenceError');end
    end
    function volumeScanProgress(pg,fraction,message)
        status.Text=message;
        if ~isempty(pg),fusiBaselineProgress('update',pg,fraction,message);else,drawnow limitrate;end
    end
    function opt=motionSettings()
        opt=struct('path',motionPath.Value,'speed',motionSpeed.Value,'amplitude',motionAmplitude.Value,'durationSec',rotationDuration.Value);
    end
    function changed(src,~)
        stopPlayback();
        if isequal(src,nativeLR),nativeSideExplicit=true;end
        if isequal(src,opacity) || isequal(src,cutoff),autoBg.Value=false;end
        if nativeConfirmed.Value,data.par.nativeColumnOneSide=lower(nativeLR.Value);end
        if isequal(src,nativeConfirmed) && ~nativeConfirmed.Value && isfield(data.par,'nativeColumnOneSide')
            data.par=rmfield(data.par,'nativeColumnOneSide');
        end
        displayControls={signs,pscCut,rangeEdit,alpha,modulate,low,high,color,smooth};
        if any(cellfun(@(h)isequal(h,src),displayControls))
            follow.Value=false;
            if isequal(src,signs)
                names={'blackbdy_iso','winter_brain_fsl','signed_blackbdy_winter'};
                color.Value=names{find(strcmp(signs.Items,signs.Value),1)};
            end
        end
        refresh();
    end
    function stackChanged(src,~)
        if isequal(src,stackCols),stackAutoLayout.Value=false;end
        stopPlayback();backend.Value='Coronal slice stack';refresh();
    end
    function stackViewChanged(~,~)
        switch stackView.Value
            case 'Paper oblique',angles=[-6 8 0];
            case 'Shallow oblique',angles=[-4 4 0];
            case 'Face-on',angles=[0 0 0];
            otherwise,angles=[stackYaw.Value stackTilt.Value stackRoll.Value];
        end
        stackYaw.Value=angles(1);stackTilt.Value=angles(2);stackRoll.Value=angles(3);
        stackChanged([],[]);applyStackCamera();refresh();
    end
    function stackAnglesChanged(~,~)
        stackView.Value='Custom';stackChanged([],[]);applyStackCamera();refresh();
    end
    function applyStackCamera()
        if isempty(surfaceAx)||~isvalid(surfaceAx)||~strcmp(currentBackend,'Coronal slice stack'),return;end
        bounds=[surfaceAx.XLim;surfaceAx.YLim;surfaceAx.ZLim];
        points=stackPoints();
        stackFitPoints=points;
        camera=fusiVolumeStackCamera(bounds,surfaceAx.Position(3:4),[stackYaw.Value stackTilt.Value stackRoll.Value],points);
        restoreCamera(camera);initialCamera=cameraState();updateDecorations();
    end
    function points=stackPoints()
        points=[];
        for handle=stackObjects
            if ~isgraphics(handle),continue;end
            [rows,cols]=find(handle.AlphaData>0);if isempty(rows),continue;end
            count=size(handle.AlphaData);x=handle.XData;y=handle.YData;z=handle.ZData;
            xp=min(x(:))+[min(cols)-1 max(cols)]/count(2)*range(x(:));
            yp=min(y(:))+[min(rows)-1 max(rows)]/count(1)*range(y(:));
            [xx,yy,zz]=ndgrid(xp,yp,[-1 1]*abs(z(1)));
            points=[points;xx(:) yy(:) zz(:)]; %#ok<AGROW>
        end
        labels=findall(surfaceAx,'Type','text');
        for j=1:numel(labels),points=[points;labels(j).Position];end %#ok<AGROW>
    end
    function fitStack(~,~)
        if isempty(surfaceAx)||~isvalid(surfaceAx)||~strcmp(currentBackend,'Coronal slice stack'),return;end
        old=cameraState();points=stackPoints();
        if isempty(points),return;end
        fit=fusiVolumeRefitStackCamera(old,points,points,surfaceAx.Position(3:4));
        forward=fit.target-fit.position;right=cross(forward,fit.up);right=right/norm(right);up=cross(right,forward/norm(forward));
        centered=points-fit.target;half=max(max(abs(centered*right'))/(surfaceAx.Position(3)/surfaceAx.Position(4)),max(abs(centered*up')));
        direction=(fit.position-fit.target)/norm(fit.position-fit.target);
        fit.position=fit.target+direction*1.15*half/tand(fit.angle/2);
        restoreCamera(fit);stackFitPoints=points;initialCamera=cameraState();updateDecorations();
    end
    function markerChanged(~,~)
        placingMarker=strcmp(lrMarker.Value,'Custom position') && ~strcmp(currentBackend,'Volume rendering');
        if placingMarker,status.Text='Click in the image, or use marker X/Y, to place the L/R marker.';fig.Pointer='crosshair';
        else,fig.Pointer='arrow';end
        updateDecorations();
    end
    function markerPositionChanged(~,~)
        markerPoint=[markerX.Value markerY.Value]/100;lrMarker.Value='Custom position';placingMarker=false;fig.Pointer='arrow';updateDecorations();
    end
    function stackTabSelected(~,event)
        if strcmp(event.NewValue.Title,'Stack'),stackChanged([],[]);end
    end
    function rulerUnitChanged(~,~)
        lengthUm=str2double(rulerLength.Value);if strcmp(lastRulerUnit,'mm'),lengthUm=lengthUm*1000;end
        if strcmp(rulerUnit.Value,'mm'),rulerLength.Items={'.05','.1','.25','.5','1','2','5'};rulerLength.Value=sprintf('%g',lengthUm/1000);
        else,rulerLength.Items={'50','100','250','500','1000','2000','5000'};rulerLength.Value=sprintf('%g',lengthUm);end
        lastRulerUnit=rulerUnit.Value;refresh();
    end
    function value=rulerLengthUm()
        value=str2double(rulerLength.Value);if strcmp(rulerUnit.Value,'mm'),value=value*1000;end
        if ~isfinite(value)||value<50||value>5000,error('deConfUSIon:RulerLength','Choose a ruler from 50 um to 5 mm.');end
    end
    function showPSCOnly(~,~)
        stopPlayback();vessels.Value=false;atlasAlpha.Value=0;pscBox.Value=true;refresh();
    end
    function followChanged(~,~)
        if follow.Value,loadDisplay(lastVideo);end
        refresh();
    end
    function syncVideo(d)
        lastVideo=d;
        if ~isvalid(fig) || ~follow.Value || isequal(d,display),return;end
        if isfield(d,'underlay') && (~isfield(display,'underlay') || ~isequal(d.underlay,display.underlay)),cachedOpt=[];anatomyKey=[];end
        loadDisplay(d);refresh();
    end
    function loadDisplay(d)
        display=d;signs.Value=polarityName(d.signMode);rangeEdit.Value=sprintf('%.6g %.6g',d.caxis);
        if ~ismember(d.colorScheme,color.Items),color.Items=[{d.colorScheme} color.Items];end
        color.Value=d.colorScheme;alpha.Value=d.alphaPct;modulate.Value=d.alphaModEnable;
        low.Value=d.modMinAbs;high.Value=d.modMaxAbs;pscCut.Value=d.maskThreshold;smooth.Value=d.overlaySmoothSigma;
    end
    function showDetails(~,~)
        details=sprintf('Voxel sampling (Y/X/Z): %.4g / %.4g / %.4g %s.\n\n%s\n\nSaved grid %s; field of view %.4g x %.4g x %.4g mm.\n\n%s', ...
            [dy.Value dx.Value dz.Value],unit.Value,c.source,mat2str(geo.shapeYXZ),geo.fieldOfViewMm,geo.resolutionStatement);
        if isfield(geo,'referenceTransmitMHz')
            details=sprintf('%s\n\nReference sequence: TX %.4g MHz; sound speed %.4g m/s; wavelength %.4g um. At nominal 15 MHz, wavelength %.4g um. Neither number is a measured resolution.\n\n%s', ...
                details,geo.referenceTransmitMHz,geo.referenceSoundSpeedMps,geo.referenceWavelengthUm,geo.nominal15MHzWavelengthUm,geo.referenceSequence);
        end
        details=sprintf('%s\n\nBaseline Doppler: reference vessels averaged over the Video baseline.\nAlpha modulation: opacity follows absolute PSC, exactly as in Video GUI.\nFaint Doppler hiding: display-only suppression of weak signal. This does not create anatomical brain segmentation.\n\nEdit spacing in the lower part of the main controls if the saved geometry needs correction.',details);
        f=uifigure('Name','3D spacing and controls','Color','k','Position',[100 100 740 700]);
        layout=uigridlayout(f,[1 1],'BackgroundColor','k');
        uitextarea(layout,'Value',splitlines(string(details)),'Editable','off','FontColor','w','BackgroundColor','k','FontSize',15);
    end
    function refresh(~,~)
        if busy,pending=true;return;end
        busy=true;
        try
            timeFields();cutoff.Enable='on';opacity.Enable='on';low.Enable=onOff(modulate.Value);high.Enable=onOff(modulate.Value);
            unit.Enable=onOff(isempty(atlasContext) && ~atlasOnly);dy.Enable=unit.Enable;dx.Enable=unit.Enable;dz.Enable=unit.Enable;
            atlasType.Enable=onOff(atlasOnly || ~isempty(atlasContext));atlasAlpha.Enable=atlasType.Enable;reviewAtlas.Enable=atlasType.Enable;
            rulerBox.Enable=onOff(strcmp(unit.Value,'mm'));rulerLength.Enable=rulerBox.Enable;
            rulerUnit.Enable=rulerBox.Enable;axesBox.Enable=rulerBox.Enable;
            selectedRulerUm=rulerLengthUm();
            opt=struct('mode',mode.Value,'frame',fr.Value,'intervalMin',[start.Value finish.Value], ...
                'slices',sscanf(sliceEdit.Value,'%f')','spacing',[dy.Value dx.Value dz.Value], ...
                'units',unit.Value,'applyMask',maskBox.Value,'applyOverlayMask',true,'underlaySource',reference.Value,'underlayPreset',underPreset.Value,'excludedSlices',sscanf(excluded.Value,'%f')');
            if isappdata(fig,'FUSIVolumeExportSlices')
                chosenSlices=getappdata(fig,'FUSIVolumeExportSlices');
                opt.slices=[min(chosenSlices) max(chosenSlices)];
                % Keep a neighbouring plane in the volume geometry when
                % exporting one slice; only selected planes remain visible.
                if opt.slices(1)==opt.slices(2)
                    opt.slices=[max(1,opt.slices(1)-1) min(nZ,opt.slices(2)+1)];
                end
                opt.excludedSlices=setdiff(1:nZ,chosenSlices);
            end
            if ~isequal(opt,cachedOpt)
                key=rmfield(opt,{'mode','frame','intervalMin'});
                reuse=isequal(key,anatomyKey) && ~opt.applyMask;
                if reuse,cachedSnapshot=fusiVolumeSnapshot(data,opt,nativeAnatomy);
                else,cachedSnapshot=fusiVolumeSnapshot(data,opt);nativeAnatomy=cachedSnapshot;anatomyKey=key;end
                cachedSnapshot=excludeSourceSlices(cachedSnapshot,opt.excludedSlices);
                nativeFrame=cachedSnapshot;
                if ~isempty(atlasContext),cachedSnapshot=atlasContext.frameMapper(cachedSnapshot,reuse);end
                if ~reuse || isempty(autoProfile),autoProfile=fusiVolumeAutoAppearance(cachedSnapshot);end
                cachedSnapshot.autoAppearance=autoProfile;
                cachedOpt=opt;
            end
            S=cachedSnapshot;
            if atlasOnly,timeStamp.Visible='off';
            else
                if S.frameCount==1,timeStamp.Text=sprintf('Time %.2f min | %.1f s',S.timeSec(1)/60,S.timeSec(1));
                else,timeStamp.Text=sprintf('Time %.2f–%.2f min',S.timeSec(1)/60,S.timeSec(end)/60);end
                if usesSequence()&&~isempty(sequence)
                    name=regexp(data.label,'scan\d+','match','once','ignorecase');if isempty(name),name=sprintf('Scan %d',sequence.active);end
                    timeStamp.Text=sprintf('%s | %.1f s',name,S.timeSec(1));
                end
                timeStamp.Visible='on';
            end
            timeStamp.Position=[max(0,renderPanel.Position(3)-240) max(0,renderPanel.Position(4)-35) 230 30];
            if atlasOnly
                S.underlay(:)=0;S.signal(:)=0;S.underlayValid(:)=false;S.psc(:)=NaN;
                S.atlasReference=data.atlasReference;S.atlasBrainMask=data.atlasBrainMask;
                S.atlasCoverageMask=false(size(S.psc));
                if strcmp(atlasType.Value,'Vascular'),S.atlasReference=data.atlasVascular;end
                S.atlasAxisOrder='row=DV, column=LR, slice=AP';S.underlaySource='Allen atlas reference anatomy';
                S.note='Complete Allen brain atlas; no acquired animal data.';S.atlasProvenance=data.atlasProvenance;
                S.atlasOnly=true;
            end
            if ~isempty(atlasContext) && strcmp(atlasType.Value,'Vascular'),S.atlasReference=atlasContext.vascular;end
            if savedAtlasGrid,S.atlasAxisOrder='row=DV, column=LR, slice=AP';end
            S.nativeLeftRight=struct('columnOneSide',lower(nativeLR.Value),'confirmed',nativeConfirmed.Value);
            S.displayLeftRight=fusiVolumeDisplayOrientation(S,nativeLR.Value,nativeConfirmed.Value,displayLR.Value);
            cr=sscanf(rangeEdit.Value,'%f')';
            if numel(cr)~=2 || any(~isfinite(cr)) || cr(1)>=cr(2)
                error('deConfUSIon:VolumeRange','Enter two increasing PSC color limits.');
            end
            d=display;d.caxis=cr;d.signMode=find(strcmp(signs.Items,signs.Value),1);
            if ~strcmp(d.colorScheme,color.Value),d.colormap=fusiVolumeColormap(color.Value);end
            d.colorScheme=color.Value;d.alphaPct=alpha.Value;d.alphaModEnable=modulate.Value;
            d.modMinAbs=low.Value;d.modMaxAbs=high.Value;d.maskThreshold=pscCut.Value;d.overlaySmoothSigma=smooth.Value;
            if strcmp(backend.Value,'Surface rendering') && voxelPSC.Value,d.overlaySmoothSigma=0;end
            settings=struct('underlayCutoff',cutoff.Value/100,'underlayOpacity',opacity.Value/100,'pscOpacity',alpha.Value/100, ...
                'showPSC',pscBox.Value,'pscCutoff',max(eps,pscCut.Value),'pscRange',cr,'sign',signs.Value, ...
                'autoBackground',autoBg.Value,'overlaySmoothSigma',d.overlaySmoothSigma,'display',d,'atlasOpacity',atlasAlpha.Value/100,'pscStrength',strength.Value,'clearPSC',clearPSC.Value, ...
                'showDoppler',vessels.Value,'underlayGamma',vesselGamma.Value,'underlayGain',vesselGain.Value,'atlasOpacityMode','overall');
            settings.displayFlipLR=S.displayLeftRight.flipColumns;
            if strcmp(backend.Value,'Coronal slice stack')
                rgba=[];a=[];v=[];
                renderInfo=struct('effectiveBackgroundCutoff',cutoff.Value/100,'effectiveVesselOpacity',opacity.Value/100, ...
                    'visibleDopplerFraction',0,'opacityRule','Slab-local alpha composition exposes internal PSC without ray occlusion.');
            else
                bgKey={anatomyKey,atlasFile,atlasType.Value,settings.underlayCutoff,settings.underlayOpacity,settings.autoBackground, ...
                    settings.atlasOpacity,settings.showDoppler,settings.underlayGamma,settings.underlayGain};
                if opt.applyMask || ~isequal(bgKey,rgbaBackgroundKey),rgbaBackground=[];end
                [rgba,a,renderInfo,v,rgbaBackground]=fusiVolumeRGBA(S,settings,rgbaBackground);
                rgbaBackgroundKey=bgKey;
            end
            if autoBg.Value,cutoff.Value=100*renderInfo.effectiveBackgroundCutoff;opacity.Value=100*renderInfo.effectiveVesselOpacity;end
            fallback='';
            plotted=S;
            if S.displayLeftRight.flipColumns && ~strcmp(backend.Value,'Coronal slice stack')
                for field={'underlay','underlayValid','signal','psc','atlasReference','atlasBrainMask','atlasCoverageMask'}
                    if isfield(plotted,field{1}),plotted.(field{1})=flip(plotted.(field{1}),2);end
                end
                rgba=flip(rgba,2);a=flip(a,2);v=flip(v,2);
            end
            if strcmp(backend.Value,'Volume rendering')
                try
                    if movieRendering
                        % Use exactly the GUI transfer without uploading this
                        % frame to the asynchronous browser canvas as well.
                        setappdata(fig,'FUSIVolumeMovieVolume',struct('Data',rgba,'AlphaData',a,'Transformation',vol.Transformation));
                    else
                        drawVolume(plotted,rgba,a);
                    end
                catch ME
                    fallback=['Volume renderer unavailable: ' ME.message ' Using surface rendering.'];
                    backend.Value='Surface rendering'; drawSurface(plotted,settings,renderInfo,v);
                end
            elseif strcmp(backend.Value,'Coronal slice stack')
                drawStack(S,settings);
            else
                drawSurface(plotted,settings,renderInfo,v);
            end
            if isempty(initialCamera),setCameraPreset(S);initialCamera=cameraState();end
            geometry=[S.spacing S.slices];
            visibleMap=fusiVolumePSCColormap(d.colormap,settings.clearPSC);
            legendKey={cr,visibleMap,settings.showPSC,d.signMode};
            if ~isequal(legendKey,lastLegend)
                legendImage.ImageSource=repmat(flipud(reshape(uint8(255*visibleMap),size(visibleMap,1),1,3)),1,12,1);
                ticks=linspace(cr(1),cr(2),5);
                for j=1:5,legendTicks(j).Text=sprintf('%.3g',ticks(j));end
                legendPanel.Visible=onOff(settings.showPSC);legendTitle.Text='PSC (%)';
                if d.signMode==2,legendTitle.Text='Negative |PSC| (%)';end
                layoutLegend();
                lastLegend=legendKey;
            end
            caption.Text=sprintf('%s\nFrames %d-%d | %.4g-%.4g min | slices %d-%d | voxel Y/X/Z = %.4g / %.4g / %.4g %s | %s', ...
                data.label,S.originalFrames(1),S.originalFrames(end),S.timeSec/60,S.slices,S.spacing,S.units,currentBackend);
            legendText='PSC (%)';if d.signMode==2,legendText='Negative PSC magnitude (%)';end
            caption.Text=sprintf('%s\n%s | baseline %.4g-%.4g s | %s | %s | %s',caption.Text,legendText,baselineLimits(data),d.colorScheme,signs.Value,S.underlaySource);
            if atlasOnly,caption.Text=sprintf('Complete Allen brain atlas | %s | sampling DV/LR/AP: %.4g / %.4g / %.4g mm\nReference anatomy only. Axis order: DV, LR, AP. No animal PSC or recording time.',atlasType.Value,S.spacing);end
            if strcmp(currentBackend,'Surface rendering') && settings.showPSC
                if voxelPSC.Value,caption.Text=sprintf('%s | Unsmoothed PSC voxel faces; exact per-voxel colors.',caption.Text);
                else,caption.Text=sprintf('%s | PSC threshold contours.',caption.Text);end
            end
            status.Text=strtrim(sprintf('%s %s Visible Doppler: %.1f%%. Changes apply immediately.',S.note,fallback,100*renderInfo.visibleDopplerFraction));
            if atlasOnly,status.Text=strtrim(['Complete reference atlas. ' fallback ' Changes apply immediately.']);end
            arrays={'underlay','underlayValid','psc','signal','atlasReference','atlasBrainMask','atlasCoverageMask'};
            metadata=rmfield(S,intersect(fieldnames(S),arrays));
            metadata.settings=settings;metadata.backend=currentBackend;
            if isappdata(fig,'FUSIVolumeExportSlices')
                metadata.exportSelectedSourceSlices=setdiff(getappdata(fig,'FUSIVolumeExportSlices'),opt.excludedSlices,'stable');
            end
            if strcmp(currentBackend,'Coronal slice stack')
                metadata.slabs=getappdata(fig,'FUSIVolumeSlabs');metadata.slabs.displayConvention=S.displayLeftRight;
                if ~isempty(metadata.slabs.requestedTimeRowMinutes)
                    caption.Text=sprintf('%s\nFixed time rows (actual min): %s | %d sections per row | %g um slabs\nPSC baseline %.4g-%.4g s | %s | %s | %s', ...
                        data.label,mat2str(metadata.slabs.timeRowMinutes,4),metadata.slabs.sectionsPerTimeRow,metadata.slabs.nominalThicknessUm, ...
                        baselineLimits(data),d.colorScheme,signs.Value,S.underlaySource);
                    metadata.originalFrames=cell2mat(metadata.slabs.timeRowFrames);metadata.timeSec=metadata.slabs.timeRowMinutes*60;metadata.frameCount=metadata.slabs.timeRows;
                end
            end
            metadata.underlayContrastPreset=underPreset.Value;
            metadata.RGBDisplayRange=[0 1];metadata.PSCColorRule='Exact Video LUT and selected PSC range; no per-frame RGB normalization.';
            finitePSC=S.psc(isfinite(S.psc));metadata.measuredPSCRange=[NaN NaN];
            if strcmp(currentBackend,'Coronal slice stack')
                slabPSC=getappdata(fig,'FUSIVolumeSlabPSC');finitePSC=slabPSC(isfinite(slabPSC));
            end
            if ~isempty(finitePSC),metadata.measuredPSCRange=double([min(finitePSC) max(finitePSC)]);end
            if ~atlasOnly
                caption.Text=sprintf('%s\nMeasured PSC %.4g to %.4g%% | grayscale: vessels / atlas; colored: PSC',caption.Text,metadata.measuredPSCRange);
            end
            metadata.scaleBar=struct('enabled',rulerBox.Value && strcmp(S.units,'mm'),'lengthUm',selectedRulerUm,'displayUnit',rulerUnit.Value,'placement',rulerPosition.Value);
            metadata.spatialAxes=axesBox.Value;metadata.unsmoothedSurfacePSC=voxelPSC.Value;
            metadata.leftRightMarker=struct('mode',lrMarker.Value,'positionFraction',markerPoint);
            metadata.viewPreset=viewChoice.Value;metadata.rendering=renderInfo;metadata.geometry=geo;metadata.followVideo=follow.Value;
            metadata.calibrationSource=c.source;
            if ~isequal(S.spacing,spacing) || ~strcmp(S.units,units)
                metadata.calibrationSource=['User-entered spacing/units. Initial metadata: ' c.source];
            end
            if ~isempty(atlasContext),metadata.calibrationSource='Atlas voxel spacing times display stride; native calibration preserved in atlas provenance.';end
            metadata.axisOrder='row(Y), column(X), slice(Z); local grid coordinates';
            if isfield(S,'atlasAxisOrder'),metadata.axisOrder=S.atlasAxisOrder;metadata.atlasReference=atlasType.Value;end
            if isfield(S,'atlasCoverageMask')
                metadata.acquiredCoverageFractionOfAtlasBrain=nnz(S.atlasCoverageMask)/max(1,nnz(S.atlasBrainMask));
            end
            metadata.videoUnderlaySource=data.underlayLabel;
            metadata.exportAnalysisFolder=fusiModelAnalysisFolder(data.par);
            metadata.baseline=data.baseline;
            if fusiBaselineReference('isExternal',data.baseline)
                r=data.baseline.reference;r=rmfield(r,intersect(fieldnames(r),{'mean','tracePower','traceFrames'}));metadata.baseline.reference=r;
            end
            metadata.TRSeconds=data.TR;
            metadata.baselineReference=data.baselineInfo;
            if ~isempty(sequence)
                metadata.scanSequence=struct('orderMode',sequence.orderMode,'normalization',sequence.normMode, ...
                    'baselineWindowSec',sequence.localWindowSec,'included',fusiScanSequence('included',sequence), ...
                    'labels',{fusiScanSequence('labels',sequence)},'activeScan',sequence.active,'originalKey',sequence.originalKey);
                metadata.scanSequence.PSCFormula='100*(voxel power - selected baseline mean)/selected baseline mean';
                for si=1:numel(sequence.scans)
                    d=sequence.scans{si};metadata.scanSequence.scans(si)=struct('file',d.file,'rawFile',d.rawFile, ...
                        'TRSec',d.TR,'rawTRSec',d.rawTR,'frameCount',d.nFrames,'nativeGrid',d.spatialSize,'key',d.key);
                end
            end
            metadata.cameraMotion=motionSettings();
            if isfield(data.par,'loadedPath'),metadata.recordingPath=data.par.loadedPath;end
            metadata.PSCMeanRule='Arithmetic mean over acquired samples; every selected sample must be finite and unmasked.';
            if strcmp(currentBackend,'Coronal slice stack')
                metadata.PSCMeanRule='Spatial slab means omit missing/excluded samples before applying the common LUT. The selected frame or interval supplies the time dimension.';
                if ~isempty(metadata.slabs.requestedTimeRowMinutes)
                    metadata.PSCMeanRule='Each time row uses one nearest acquired frame. Spatial slab means omit missing/excluded samples before applying the common LUT.';
                end
            end
            if atlasOnly
                metadata=rmfield(metadata,intersect(fieldnames(metadata),{'originalFrames','dataFrames','frameCount','timeSec','baseline','TRSeconds','baselineReference','PSCMeanRule','underlayRange'}));
                metadata.dataKind='Static reference atlas; no animal recording or functional response';
            end
            setappdata(fig,'FUSIVolumeExport',struct('scene',scene,'viewer',renderer,'axes',surfaceAx,'metadata',metadata));
            setappdata(fig,'FUSIVolumeSnapshot',S);updateDecorations();
            if isappdata(fig,'FUSIVolumeLastError'),rmappdata(fig,'FUSIVolumeLastError');end
            png.Enable='on';mp4.Enable='on';timeMovie.Enable=onOff(~atlasOnly);
            if isappdata(fig,'FUSIVolumeExportLock'),lock=getappdata(fig,'FUSIVolumeExportLock');lock();end
            drawnow limitrate;
        catch ME
            setappdata(fig,'FUSIVolumeLastError',ME);
            status.Text=ME.message;png.Enable='off';mp4.Enable='off';timeMovie.Enable='off';stopPlayback();
        end
        busy=false;if pending,pending=false;refresh();end
    end
    function newBackend(which)
        if strcmp(currentBackend,which),return;end
        % Remove listeners before destroying the web canvas. Its queued
        % camera events must not move a replacement native/atlas viewer.
        if ~isempty(decorListeners),delete(decorListeners(isvalid(decorListeners)));end
        decorListeners=[];
        if ~isempty(renderer) && isvalid(renderer),delete(renderer);end
        if ~isempty(surfaceAx) && isvalid(surfaceAx),delete(surfaceAx);end
        renderer=[];surfaceAx=[];vol=[];currentBackend=which;geometry=[];initialCamera=[];surfaceKey=[];stackKey=[];stackObjects=[];stackFitPoints=[];stackLayoutKey=[];
        voxelMask=[];voxelMesh=[];voxelIndices=[];voxelPatch=[];
        rgbaBackground=[];rgbaBackgroundKey=[];
        delete(findall(renderPanel,'Tag','FUSIVolumeDecoration'));decorListeners=[];
        delete(findall(renderPanel,'Tag','VolumeOrientationMarker'));
        delete(findall(rulerPanel,'Tag','FUSIVolumeDecoration'));
        fig.WindowButtonDownFcn=[];fig.WindowButtonMotionFcn=[];fig.WindowButtonUpFcn=[];fig.WindowScrollWheelFcn=[];renderPanel.SizeChangedFcn=[];renderPanel.AutoResizeChildren='off';
    end
    function timeFields()
        if atlasOnly,fr.Enable='off';start.Enable='off';finish.Enable='off';return;end
        if strcmp(mode.Value,'Frame')
            fr.Enable='on';start.Enable='off';finish.Enable='off';
        else
            fr.Enable='off';start.Enable='on';finish.Enable='on';
        end
    end
    function drawVolume(S,rgb,a)
        newBackend('Volume rendering');
        if isempty(renderer)
            renderer=viewer3d(renderPanel,'Units','pixels','Position',[0 0 max(1,renderPanel.Position(3)) max(1,renderPanel.Position(4))], ...
                'BackgroundColor','k','BackgroundGradient','off');
            renderer.SizeChangedFcn=@(~,~)updateDecorations();
            renderPanel.SizeChangedFcn=@(~,~)resizeVolume();
            % Create the label above the new web canvas, not behind it.
            timeStamp.Parent=fig;timeStamp.Parent=renderPanel;
        end
        % The web canvas consumes mouse events before figure callbacks.
        % Use its native controller; atlas installation recreates the canvas.
        renderer.BackgroundColor=[0 0 0];renderer.BackgroundGradient='off';
        renderer.Box=onOff(axesBox.Value && strcmp(S.units,'mm'));renderer.Denoising='off';
        if isempty(decorListeners)
            decorListeners=addlistener(renderer,'CameraMoved',@cameraMoved);
        end
        sameGeometry=isequal(geometry,[S.spacing S.slices]);
        if ~isempty(vol) && isvalid(vol) && sameGeometry
            % Keep the browser renderer and its interaction handlers alive.
            % Recreating volshow for each edit/frame can interrupt dragging.
            vol.Data=rgb;vol.AlphaData=a;drawnow limitrate nocallbacks;return;
        elseif ~isempty(vol) && isvalid(vol)
            delete(vol);
        end
        if ~sameGeometry,initialCamera=[];end
        T=eye(4);T(1,1)=S.spacing(2);T(2,2)=S.spacing(1);T(3,3)=S.spacing(3);
        T(3,4)=(S.slices(1)-1)*S.spacing(3);
        vol=volshow(rgb,'Parent',renderer,'RenderingStyle','VolumeRendering', ...
            'AlphaData',a,'DataLimits',[0 1],'SpecularReflectance',0,'Transformation',affinetform3d(T));
        % VOLSHOW resets viewer interactions. Install our controller after it.
        renderer.Interactions='all';installVolumeInteractions();
        if strcmp(S.units,'mm'),renderer.SpatialUnits='mm';else,renderer.SpatialUnits='pixels';end
        renderer.ScaleBar='off'; % A fixed, calibrated ruler replaces the adaptive native one.
        renderer.CameraPositionMode='auto';renderer.CameraTargetMode='auto';renderer.CameraUpVectorMode='auto';renderer.CameraZoom=.9;
        drawnow;
    end
    function resizeVolume()
        if ~isempty(renderer) && isvalid(renderer)
            renderer.Position=[0 0 max(1,renderPanel.Position(3)) max(1,renderPanel.Position(4))];updateDecorations();
        end
        timeStamp.Position=[max(0,renderPanel.Position(3)-240) max(0,renderPanel.Position(4)-35) 230 30];
    end
    function drawSurface(S,s,ri,v)
        newBackend('Surface rendering');
        if isempty(surfaceAx)
            renderPanel.AutoResizeChildren='off';
            surfaceAx=uiaxes(renderPanel,'Units','pixels','PositionConstraint','innerposition', ...
                'Position',[65 55 max(100,renderPanel.Position(3)-100) max(100,renderPanel.Position(4)-95)], ...
                'Color','k','XColor','w','YColor','w','ZColor','w','FontSize',13);
            surfaceAx.Interactions=zoomInteraction;
            axtoolbar(surfaceAx,{'rotate','zoomin','zoomout','restoreview'});
            renderPanel.SizeChangedFcn=@(~,~)resizeSurface();
            installSurfaceInteractions();
            decorListeners=[addlistener(surfaceAx,'CameraPosition','PostSet',@(~,~)updateDecorations()); ...
                addlistener(surfaceAx,'CameraViewAngle','PostSet',@(~,~)updateDecorations())];
        end
        old=[];
        if isequal(geometry,[S.spacing S.slices]) && ~isempty(surfaceAx.Children),old=cameraState();else,initialCamera=[];end
        key={S.signal,S.spacing,S.slices,ri.effectiveBackgroundCutoff,ri.effectiveVesselOpacity,s.atlasOpacity,atlasType.Value,s.showDoppler,s.displayFlipLR};
        if isfield(S,'atlasBrainMask'),key=[key {S.atlasBrainMask}];end
        hold(surfaceAx,'on');
        if ~isequal(key,surfaceKey)
            cla(surfaceAx);surfaceKey=key;
            if isfield(S,'atlasBrainMask')
                surfacePatch(single(S.atlasBrainMask),.5,[.75 .78 .82],s.atlasOpacity,'SurfaceStatic');
                if strcmp(atlasType.Value,'Vascular'),surfacePatch(S.atlasReference,.25,[.92 .94 1],.6,'SurfaceStatic');end
            end
            if ~atlasOnly && s.showDoppler,surfacePatch(S.signal,max(eps,ri.effectiveBackgroundCutoff),[.78 .82 .88], ...
                    min(.85,1-(1-ri.effectiveVesselOpacity)^12),'SurfaceStatic');end
            camlight(surfaceAx,'headlight');lighting(surfaceAx,'gouraud');
        else
            if ~voxelPSC.Value,delete(findall(surfaceAx,'Tag','SurfacePSC'));end
        end
        if s.showPSC && voxelPSC.Value
            drawVoxelPSC(v,s);
            title(surfaceAx,'Unsmoothed PSC voxels','Color','w','FontSize',13);
        elseif s.showPSC
            v(~isfinite(v))=0;
            threshold=max(eps,s.display.maskThreshold);
            if s.display.alphaModEnable
                threshold=max(threshold,s.display.modMinAbs+.35*max(eps,s.display.modMaxAbs-s.display.modMinAbs));
            end
            if ~strcmp(s.sign,'Negative'),addPSC(v,threshold,1);end
            if ~strcmp(s.sign,'Positive'),addPSC(-v,threshold,-1);end
            title(surfaceAx,'PSC contours with Video colors and opacity','Color','w','FontSize',13);
        elseif atlasOnly,delete(findall(surfaceAx,'Tag','SurfacePSC'));title(surfaceAx,['Complete Allen brain atlas | ' atlasType.Value],'Color','w');
        else,delete(findall(surfaceAx,'Tag','SurfacePSC'));title(surfaceAx,'Baseline vascular surface','Color','w');end
        hold(surfaceAx,'off');axis(surfaceAx,'equal');axis(surfaceAx,'vis3d');grid(surfaceAx,'off');
        xlim(surfaceAx,[0 (size(S.underlay,2)+1)*S.spacing(2)]);
        ylim(surfaceAx,[0 (size(S.underlay,1)+1)*S.spacing(1)]);
        zlim(surfaceAx,[(S.slices(1)-1) (S.slices(2)+1)]*S.spacing(3));
        xlabel(surfaceAx,['Column X (' S.units ')']);ylabel(surfaceAx,['Row Y (' S.units ')']);zlabel(surfaceAx,['Slice Z (' S.units ')']);
        if isfield(S,'atlasAxisOrder'),xlabel(surfaceAx,'Atlas left/right (mm)');ylabel(surfaceAx,'Dorsal/ventral (mm)');zlabel(surfaceAx,'Anterior/posterior (mm)');end
        surfaceAx.Visible=onOff(axesBox.Value);
        if isempty(old)
            % VIS3D freezes the automatic camera. Fit explicitly after the
            % physical limits are installed, rather than keeping the small
            % default axes camera inside the atlas surface.
            center=[(size(S.underlay,2)+1)*S.spacing(2)/2 (size(S.underlay,1)+1)*S.spacing(1)/2 mean(S.slices)*S.spacing(3)];
            radius=norm(size(S.underlay).*S.spacing)/2;direction=[-.6 -.7 .45];direction=direction/norm(direction);
            surfaceAx.CameraTarget=center;surfaceAx.CameraPosition=center+3.5*radius*direction;
            surfaceAx.CameraUpVector=[0 -1 0];surfaceAx.CameraViewAngle=35;
        else,restoreCamera(old);end
        function surfacePatch(V,threshold,col,ap,tag)
            if ap<=0 || ~any(V(:)>=threshold),return;end
            fv=fusiVolumeSurfaceMesh(V,threshold,S.spacing,S.slices);
            if isempty(fv.vertices),return;end
            patch(surfaceAx,fv,'FaceColor',col,'EdgeColor','none','FaceAlpha',ap,'Tag',tag,'HitTest','off','PickableParts','none');
        end
        function addPSC(V,threshold,polarity)
            peak=max(V(:));
            floorValue=max(eps,s.display.maskThreshold);
            if s.display.alphaModEnable,floorValue=max(floorValue,s.display.modMinAbs);end
            if peak<=floorValue,return;end
            level=min(threshold,(floorValue+peak)/2);
            transfer=s.display;transfer.colormap=fusiVolumePSCColormap(transfer.colormap,s.clearPSC);
            [~,ap,col]=fusiOverlayAppearance(polarity*level,transfer,1);
            limit=s.display.alphaPct/100;
            if s.clearPSC && limit>0,ap=limit*sqrt(ap/limit);end
            ap=min(limit,ap*s.pscStrength);
            surfacePatch(V,level,reshape(col,1,3),ap,'SurfacePSC');
        end
        function drawVoxelPSC(V,settings)
            transfer=settings.display;transfer.colormap=fusiVolumePSCColormap(transfer.colormap,settings.clearPSC);
            [~,ap,rgb]=fusiOverlayAppearance(double(V),transfer,1);limit=transfer.alphaPct/100;
            if settings.clearPSC && limit>0,ap=limit*sqrt(ap/limit);end
            ap=min(limit,ap*settings.pscStrength);mask=isfinite(V)&ap>0;
            if ~isequal(mask,voxelMask)
                [voxelMesh,voxelIndices]=fusiVolumeVoxelFaces(mask,S.spacing,S.slices);voxelMask=mask;
                if isgraphics(voxelPatch),delete(voxelPatch);end;voxelPatch=[];
            end
            if isempty(voxelIndices),return;end
            colors=reshape(rgb,[],3);colors=colors(voxelIndices,:);opacities=ap(voxelIndices);
            if isempty(voxelPatch)||~isgraphics(voxelPatch)
                delete(findall(surfaceAx,'Tag','SurfacePSC'));
                voxelPatch=patch(surfaceAx,voxelMesh,'FaceColor','flat','FaceVertexCData',colors, ...
                    'FaceAlpha','flat','FaceVertexAlphaData',opacities,'AlphaDataMapping','none', ...
                    'FaceLighting','none','EdgeColor','none','Tag','SurfacePSC','HitTest','off','PickableParts','none');
            else,voxelPatch.FaceVertexCData=colors;voxelPatch.FaceVertexAlphaData=opacities;end
        end
    end
    function surfaceScroll(~,evt)
        if (isempty(surfaceAx)||~isvalid(surfaceAx)) && (isempty(renderer)||~isvalid(renderer)),return;end
        p=getpixelposition(renderPanel,true);q=fig.CurrentPoint;
        if q(1)<p(1)||q(1)>sum(p([1 3]))||q(2)<p(2)||q(2)>sum(p([2 4])),return;end
        if ~isempty(renderer)&&isvalid(renderer),renderer.CameraZoom=min(30,max(.05,renderer.CameraZoom/1.12^evt.VerticalScrollCount));
        else,surfaceAx.CameraViewAngle=min(100,max(.5,surfaceAx.CameraViewAngle*1.12^evt.VerticalScrollCount));end
        updateDecorations();
    end
    function installSurfaceInteractions()
        fig.WindowButtonDownFcn=@beginOrbit;fig.WindowButtonMotionFcn=@dragOrbit;
        fig.WindowButtonUpFcn=@(~,~)endOrbit();fig.WindowScrollWheelFcn=@surfaceScroll;
        setappdata(fig,'FUSIVolumeOrbit',@orbit);
    end
    function beginOrbit(~,~)
        if (isempty(surfaceAx)||~isvalid(surfaceAx)) && (isempty(renderer)||~isvalid(renderer)),return;end
        p=getpixelposition(renderPanel,true);q=fig.CurrentPoint;
        if q(1)>=p(1)&&q(1)<=p(1)+p(3)&&q(2)>=p(2)&&q(2)<=p(2)+p(4)
            if placingMarker
                markerPoint=(q-p(1:2))./p(3:4);markerX.Value=100*markerPoint(1);markerY.Value=100*markerPoint(2);
                placingMarker=false;fig.Pointer='arrow';updateDecorations();return;
            end
            dragPoint=q;fig.Pointer='fleur';
        end
    end
    function dragOrbit(~,~)
        if isempty(dragPoint),return;end
        q=fig.CurrentPoint;delta=q-dragPoint;dragPoint=q;orbit(delta(1),delta(2));
    end
    function orbit(horizontal,vertical)
        if ~isempty(renderer)&&isvalid(renderer)
            offset=renderer.CameraPosition-renderer.CameraTarget;
            up=renderer.CameraUpVector/norm(renderer.CameraUpVector);
            offset=rotateVector(offset,up,-.35*horizontal);
            right=cross(-offset,up);right=right/norm(right);
            offset=rotateVector(offset,right,-.35*vertical);up=rotateVector(up,right,-.35*vertical);
            renderer.CameraPositionMode='manual';renderer.CameraUpVectorMode='manual';
            renderer.CameraPosition=renderer.CameraTarget+offset;renderer.CameraUpVector=up;updateDecorations();return;
        end
        if isempty(surfaceAx)||~isvalid(surfaceAx),return;end
        camorbit(surfaceAx,-.35*horizontal,-.35*vertical,'camera');updateDecorations();
    end
    function endOrbit()
        dragPoint=[];if isvalid(fig),fig.Pointer='arrow';end
    end
    function S=excludeSourceSlices(S,indices)
        if isempty(indices),return;end
        if any(~isfinite(indices)|indices~=round(indices)|indices<1|indices>nZ)
            error('deConfUSIon:ExcludedSlices','Excluded slices must be original integer slice numbers within the recording.');
        end
        local=unique(indices)-S.slices(1)+1;local=local(local>=1 & local<=size(S.psc,3));
        S.psc(:,:,local)=NaN;S.underlayValid(:,:,local)=false;S.signal(:,:,local)=0;S.underlay(:,:,local)=0;
        S.excludedSourceSlices=unique(indices);
    end
    function drawStack(S,s)
        newBackend('Coronal slice stack');
        if isempty(surfaceAx)
            renderPanel.AutoResizeChildren='off';
            surfaceAx=uiaxes(renderPanel,'Units','pixels','PositionConstraint','innerposition', ...
                'Position',[25 25 max(100,renderPanel.Position(3)-50) max(100,renderPanel.Position(4)-50)],'Color','k');
            surfaceAx.Interactions=zoomInteraction;surfaceAx.Visible='off';
            renderPanel.SizeChangedFcn=@(~,~)resizeSurface();installSurfaceInteractions();
        end
        range=sscanf(stackRange.Value,'%f')';defaultRange=isempty(range);
        if atlasOnly,stepUm=double(data.atlasFull.VoxelSize(1));
        elseif isempty(atlasContext),stepUm=S.spacing(3)*1000;
        else,stepUm=double(atlasContext.provenance.scanGeometry.atlasVoxelSizeUm(1));end
        if strcmp(slabMode.Value,'Slice count'),thickness=slabCount.Value*stepUm;slabWidth.Value=thickness;
        else,thickness=slabWidth.Value;slabCount.Value=max(1,round(thickness/stepUm));end
        slabCount.Enable=onOff(strcmp(slabMode.Value,'Slice count'));slabWidth.Enable=onOff(strcmp(slabMode.Value,'Physical width'));
        if atlasOnly
            count=size(data.atlasFull.Histology,1);base=1;
            if isempty(range),range=[1 count];end
        elseif isempty(atlasContext)
            count=size(S.psc,3);base=S.slices(1);
            if isempty(range),range=[base base+count-1];end
        else
            count=atlasContext.provenance.atlasOriginalSizeAPDVLR(1);base=1;
            if isempty(range)
                support=find(squeeze(any(any(S.atlasCoverageMask & atlasContext.brainMask,1),2)));
                if isempty(support),support=find(squeeze(any(any(atlasContext.brainMask,1),2)));end
                stride=atlasContext.provenance.displayStride;
                range=1+(support([1 end])'-1)*stride;
            end
        end
        if defaultRange
            samples=max(1,round(thickness/stepUm));
            if samples<=count,range=[max(range(1),base+floor((samples-1)/2)) min(range(2),base+count-1-ceil((samples-1)/2))];end
        end
        if numel(range)~=2||any(~isfinite(range))||range(1)<base||range(2)>base+count-1||range(1)>range(2)
            error('deConfUSIon:SlabRange','Enter first and last slab centers within the current atlas or native slice grid.');
        end
        centers=unique(round(linspace(range(1),range(2),stackTiles.Value)));
        if atlasOnly,slabs=fusiAtlasReferenceSlabs(data.atlasFull,centers,thickness,atlasType.Value);
        elseif isempty(atlasContext),slabs=fusiVolumeSlabMean(S,centers-base+1,thickness);
        else,slabs=atlasContext.slabMapper(nativeFrame,centers,thickness,atlasType.Value);end
        if atlasOnly,sampling=double(data.atlasFull.VoxelSize([2 3]))/1000;
        elseif isempty(atlasContext),sampling=S.spacing(1:2);else,sampling=double(atlasContext.provenance.scanGeometry.atlasVoxelSizeUm([2 3]))/1000;end
        rows=size(slabs.anatomy,1);cols=size(slabs.anatomy,2);width=cols*sampling(2);height=rows*sampling(1);
        % Figure 6c repeats the same sections at several time points. Keep
        % time rows distinct from averaging neighbouring spatial samples.
        requestedTimes=sscanf(strrep(stackTimes.Value,',',' '),'%f')';
        if ~isempty(strtrim(stackTimes.Value)) && isempty(requestedTimes)
            error('deConfUSIon:StackTimes','Enter recording times in minutes, or leave Time rows blank.');
        end
        if atlasOnly && ~isempty(requestedTimes)
            error('deConfUSIon:StackTimes','The reference atlas has no recording time. Leave Time rows blank.');
        end
        slabRows={slabs};rowFrames={S.originalFrames};rowTimes=mean(S.timeSec)/60;
        if ~isempty(requestedTimes)
            acquiredTimes=(0:numel(1:max(1,round(data.interpol)):size(data.PSC,4))-1)*data.TR/60;
            if numel(requestedTimes)>8 || any(~isfinite(requestedTimes)) || any(requestedTimes<0 | requestedTimes>acquiredTimes(end)+1e-6)
                error('deConfUSIon:StackTimes','Choose up to eight recording times inside 0 to %g min.',acquiredTimes(end));
            end
            [~,frames]=min(abs(acquiredTimes(:)-requestedTimes),[],1);
            rowFrames=num2cell(frames);rowTimes=acquiredTimes(frames);slabRows=cell(1,numel(frames));
            frameOptions=rmfield(cachedOpt,{'frame','mode','intervalMin'});
            mapping=[];if ~isempty(atlasContext),mapping=atlasContext.provenance;end
            rowDataKey={frames,centers,thickness,frameOptions,atlasType.Value,mapping};
            if isequal(rowDataKey,stackDataKey)
                slabRows=stackDataRows;
            else
            for ti=1:numel(frames)
                options=cachedOpt;options.mode='Frame';options.frame=frames(ti);
                native=fusiVolumeSnapshot(data,options,nativeAnatomy);
                native=excludeSourceSlices(native,options.excludedSlices);
                if isempty(atlasContext),slabRows{ti}=fusiVolumeSlabMean(native,centers-base+1,thickness);
                else,slabRows{ti}=atlasContext.slabMapper(native,centers,thickness,atlasType.Value);end
            end
            stackDataKey=rowDataKey;stackDataRows=slabRows;
            end
        end
        layout=fusiVolumeStackLayout(numel(centers),numel(slabRows),[width height],surfaceAx.Position(3:4), ...
            stackCols.Value,stackAutoLayout.Value,stackGap.Value,stackStagger.Value);
        ncols=layout.columns;strips=layout.strips;
        tileCount=numel(centers)*numel(slabRows);
        rowKey=[];if ~isempty(requestedTimes),rowKey=rowFrames;end
        key={centers,slabWidth.Value,slabDepthGain.Value,stackGap.Value,stackStagger.Value,ncols,atlasType.Value,S.spacing,S.slices,nativeLR.Value,nativeConfirmed.Value,rulerBox.Value,rulerLength.Value,rulerUnit.Value,rowKey,stackLabels.Value};
        firstLayout=isempty(stackKey);recreate=~isequal(key,stackKey)||numel(stackObjects)~=tileCount;
        old=cameraState();
        if recreate
            cla(surfaceAx);stackKey=key;stackObjects=gobjects(1,tileCount);stackBackObjects=gobjects(1,tileCount);stackSideObjects=gobjects(1,tileCount);hold(surfaceAx,'on');
        end
        for ti=1:numel(slabRows)
        slabs=slabRows{ti};
        for k=1:numel(centers)
            objectIndex=(ti-1)*numel(centers)+k;
            tissue=slabs.anatomy(:,:,k);
            if isfield(S,'atlasReference'),u=max(0,min(1,tissue));
            else,u=min(1,max(0,tissue).^s.underlayGamma*s.underlayGain);end
            slabRGB=repmat(u,1,1,3);ap=zeros(size(u),'single');
            if s.showPSC
                p=slabs.psc(:,:,k);
                if s.overlaySmoothSigma>0
                    finite=isfinite(p);p(~finite)=0;p=imgaussfilt(p,s.overlaySmoothSigma);p(~finite)=NaN;
                end
                [~,ap,rgb]=fusiOverlayAppearance(double(p),s.display,1);
                limit=s.display.alphaPct/100;
                if s.clearPSC&&limit>0,ap=limit*sqrt(ap/limit);end
                ap=min(limit,ap*s.pscStrength);slabRGB=slabRGB.*(1-ap)+squeeze(rgb).*ap;
            end
            % Apply the selected presentation convention to RGB only.
            flipDisplay=S.displayLeftRight.flipColumns;
            displayBrain=slabs.brain(:,:,k);
            if flipDisplay,slabRGB=flip(slabRGB,2);displayBrain=flip(displayBrain,2);u=flip(u,2);end
            column=mod(k-1,ncols);row=(ti-1)*strips+floor((k-1)/ncols);
            x=layout.origins(objectIndex,1);y=layout.origins(objectIndex,2);
            depth=slabs.actualThicknessUm(k)/1000*slabDepthGain.Value;
            if recreate
                stackObjects(objectIndex)=surface(surfaceAx,[x x+width;x x+width],[y y;y+height y+height],ones(2)*-depth/2, ...
                    'CData',slabRGB,'FaceColor','texturemap','EdgeColor','none','FaceAlpha','texturemap', ...
                    'AlphaData',single(displayBrain),'AlphaDataMapping','none','HitTest','off','PickableParts','none','Tag','SlabTexture');
                stackBackObjects(objectIndex)=surface(surfaceAx,[x x+width;x x+width],[y y;y+height y+height],ones(2)*depth/2, ...
                    'CData',slabRGB,'FaceColor','texturemap','EdgeColor','none','FaceAlpha','texturemap', ...
                    'AlphaData',single(displayBrain),'AlphaDataMapping','none','HitTest','off','PickableParts','none','Tag','SlabBackTexture');
                stackSideObjects(objectIndex)=patch(surfaceAx,'Vertices',zeros(0,3),'Faces',zeros(0,4), ...
                    'FaceColor','flat','EdgeColor','none','FaceLighting','none','HitTest','off','PickableParts','none','Tag','SlabTissueWalls');
                label=sprintf('%d-%d | %g um',slabs.indices{k}([1 end]),slabs.actualThicknessUm(k));
                if stackLabels.Value
                    text(surfaceAx,x+width/2,y+height*1.08,0,label,'Color','w','HorizontalAlignment','center','FontSize',10,'HitTest','off','Tag','SlabLabel');
                end
                if k==1 && ~isempty(requestedTimes)
                    text(surfaceAx,x-width*.15,y+height*.45,0,sprintf('%.4g min\nFrame %d',rowTimes(ti),rowFrames{ti}), ...
                        'Color','w','FontSize',13,'HorizontalAlignment','right','Tag','SlabTimeLabel','HitTest','off');
                end
                if rulerBox.Value && strcmp(S.units,'mm') && k==ncols && ti==1
                    lengthMm=rulerLengthUm()/1000;
                    line(surfaceAx,x+width*.92+[-lengthMm 0],[y+height*1.32 y+height*1.32],[0 0],'Color','w','LineWidth',2,'HitTest','off');
                    text(surfaceAx,x+width*.92,y+height*1.22,0,rulerLabel(rulerLengthUm()),'Color','w','FontSize',10,'HorizontalAlignment','right','HitTest','off');
                end
            else
                stackObjects(objectIndex).CData=slabRGB;stackObjects(objectIndex).AlphaData=single(displayBrain);
                stackBackObjects(objectIndex).CData=slabRGB;stackBackObjects(objectIndex).AlphaData=single(displayBrain);
            end
            wall=stackSideObjects(objectIndex);previous=wall.UserData;
            if isempty(previous)||~isequal(previous.mask,displayBrain)
                [mesh,pixels]=fusiVolumeSlabGeometry(displayBrain,sampling,depth,[x y]);
                wall.Vertices=mesh.vertices;wall.Faces=mesh.faces;wall.UserData=struct('mask',displayBrain,'pixels',pixels);
            else,pixels=previous.pixels;end
            wall.FaceVertexCData=repmat(double(u(pixels))*.7,1,3);
        end
        end
        if recreate
            hold(surfaceAx,'off');axis(surfaceAx,'equal');axis(surfaceAx,'tight');axis(surfaceAx,'vis3d');
            newPoints=stackPoints();layoutKey=[numel(centers) numel(slabRows) ncols];
            if firstLayout||isempty(old),applyStackCamera();
            elseif stackAutoFit.Value && ~isequal(layoutKey,stackLayoutKey)
                restoreCamera(fusiVolumeRefitStackCamera(old,stackFitPoints,newPoints,surfaceAx.Position(3:4)));
                stackFitPoints=newPoints;
            else,restoreCamera(old);end
            stackFitPoints=newPoints;
            stackLayoutKey=layoutKey;
        elseif ~isempty(old),restoreCamera(old);end
        stackNote.Text=sprintf('%d sections x %d time rows. %d samples/slab; %g um physical width (%g um sampling). Depth display: %gx. PSC is averaged before coloring; missing/excluded samples are omitted.',numel(centers),numel(slabRows),slabs.samplesPerSlab,slabs.nominalThicknessUm,slabs.sampleSpacingUm,slabDepthGain.Value);
        rowPSC=cellfun(@(a)a.psc,slabRows,'UniformOutput',false);
        setappdata(fig,'FUSIVolumeSlabPSC',cat(4,rowPSC{:}));
        slabMetadata=rmfield(slabs,{'psc','anatomy','brain'});
        slabMetadata.timeRowFrames=rowFrames;slabMetadata.timeRowMinutes=rowTimes;slabMetadata.requestedTimeRowMinutes=requestedTimes;
        slabMetadata.timeRows=numel(slabRows);slabMetadata.sectionsPerTimeRow=numel(centers);
        slabMetadata.showSliceRangeLabels=stackLabels.Value;
        slabMetadata.depthDisplayGain=slabDepthGain.Value;
        slabMetadata.renderedThicknessUm=slabs.actualThicknessUm*slabDepthGain.Value;
        slabMetadata.sampleSpacingYXZUm=[sampling*1000 stepUm];
        slabMetadata.tileGapPercent=stackGap.Value;slabMetadata.cameraPreset=stackView.Value;
        slabMetadata.tileStaggerPercent=stackStagger.Value;
        slabMetadata.cameraAnglesDeg=[stackYaw.Value stackTilt.Value stackRoll.Value];
        slabMetadata.automaticLayout=stackAutoLayout.Value;slabMetadata.columnsPerStrip=ncols;
        setappdata(fig,'FUSIVolumeSlabs',slabMetadata);
    end
    function installVolumeInteractions()
        fig.WindowButtonDownFcn=[];fig.WindowButtonMotionFcn=[];fig.WindowButtonUpFcn=[];fig.WindowScrollWheelFcn=[];
        setappdata(fig,'FUSIVolumeOrbit',@orbit);
    end
    function v=rotateVector(v,axis,degrees)
        angle=deg2rad(degrees);v=v*cos(angle)+cross(axis,v)*sin(angle)+axis*dot(axis,v)*(1-cos(angle));
    end
    function value=rulerLabel(lengthUm)
        if strcmp(rulerUnit.Value,'mm'),value=sprintf('%g mm',lengthUm/1000);
        else,value=sprintf('%g %cm',lengthUm,181);end
    end
    function alignCamera(~,~)
        stopPlayback();S=getappdata(fig,'FUSIVolumeSnapshot');if isempty(S),return;end
        if strcmp(currentBackend,'Coronal slice stack')
            if strcmp(viewChoice.Value,'Oblique'),stackView.Value='Paper oblique';stackViewChanged([],[]);
            elseif strcmp(viewChoice.Value,'Coronal'),stackView.Value='Face-on';stackViewChanged([],[]);
            else
                stackYaw.Value=0;stackTilt.Value=80;stackRoll.Value=0;
                if strcmp(viewChoice.Value,'Sagittal'),stackYaw.Value=80;stackTilt.Value=0;end
                if strcmp(viewChoice.Value,'Dorsal oblique'),stackYaw.Value=15;stackTilt.Value=65;end
                if strcmp(viewChoice.Value,'Sagittal oblique'),stackYaw.Value=65;stackTilt.Value=15;end
                if strcmp(viewChoice.Value,'Coronal oblique'),stackYaw.Value=10;stackTilt.Value=10;end
                stackAnglesChanged([],[]);
            end
            return;
        end
        setCameraPreset(S);initialCamera=cameraState();updateDecorations();
    end
    function setCameraPreset(S)
        if strcmp(currentBackend,'Coronal slice stack'),return;end
        center=[(size(S.underlay,2)+1)*S.spacing(2)/2 (size(S.underlay,1)+1)*S.spacing(1)/2 mean(S.slices)*S.spacing(3)];
        radius=norm(size(S.underlay).*S.spacing)/2;
        switch viewChoice.Value
            case 'Oblique',direction=[-.6 -.7 .45];direction=direction/norm(direction);up=[0 -1 0];
            case 'Dorsal',direction=[0 -1 0];up=[0 0 1];
            case 'Coronal',direction=[0 0 -1];up=[0 -1 0];
            case 'Sagittal',direction=[-1 0 0];up=[0 -1 0];
            case 'Dorsal oblique',direction=[-.3 -1 .3];up=[0 0 1];
            case 'Sagittal oblique',direction=[-1 -.3 -.3];up=[0 -1 0];
            case 'Coronal oblique',direction=[-.3 -.2 -1];up=[0 -1 0];
        end
        direction=direction/norm(direction);
        if ~isempty(renderer) && isvalid(renderer)
            renderer.Interactions='all';
            renderer.CameraTarget=center;renderer.CameraPosition=center+3*radius*direction;renderer.CameraUpVector=up;renderer.CameraZoom=.9;
        elseif ~isempty(surfaceAx) && isvalid(surfaceAx)
            surfaceAx.CameraTarget=center;surfaceAx.CameraPosition=center+3*radius*direction;surfaceAx.CameraUpVector=up;surfaceAx.CameraViewAngle=35;
        end
        updateDecorations();
    end
    function cameraMoved(source,event)
        if ~isvalid(fig) || isempty(renderer) || ~isvalid(renderer) || ~isequal(source,renderer),return;end
        % R2023b's web canvas can move without updating public camera
        % properties. Persist its event coordinates so refresh, decorations
        % and exported movies use the angle the user actually selected.
        fusiVolumeRememberCamera(renderer,event);
        updateDecorations();
    end
    function updateDecorations()
        if ~isvalid(fig),return;end
        timeStamp.Position=[max(0,renderPanel.Position(3)-240) max(0,renderPanel.Position(4)-35) 230 30];
        if ~isempty(renderer) && isvalid(renderer)
            required=[0 0 max(1,renderPanel.Position(3)) max(1,renderPanel.Position(4))];
            if ~isequal(renderer.Position,required),renderer.Position=required;end
        end
        S=getappdata(fig,'FUSIVolumeSnapshot');if isempty(S),return;end
        if strcmp(currentBackend,'Coronal slice stack')
            delete(findall(renderPanel,'Tag','VolumeHemisphere'));
            delete(findall(rulerPanel,'Tag','FUSIVolumeDecoration'));updateOrientationMarker(S);return;
        end
        decorationCamera=renderer;
        if ~isempty(renderer) && isvalid(renderer) && isappdata(fig,'FUSIVolumeMovieCamera')
            decorationCamera=getappdata(fig,'FUSIVolumeMovieCamera');
        end
        fusiVolumeDecorations(renderPanel,decorationCamera,surfaceAx,S,rulerBox.Value,rulerLengthUm(),rulerPanel,rulerUnit.Value,axesBox.Value,rulerPosition.Value);
        if ~strcmp(lrMarker.Value,'Automatic'),set(findall(renderPanel,'Tag','VolumeHemisphere'),'Visible','off');end
        updateOrientationMarker(S);
    end
    function updateOrientationMarker(S)
        label=findall(renderPanel,'Tag','VolumeOrientationMarker');
        if isappdata(fig,'FUSIVolumeExport')
            state=getappdata(fig,'FUSIVolumeExport');state.metadata.leftRightMarker=struct('mode',lrMarker.Value,'positionFraction',markerPoint);setappdata(fig,'FUSIVolumeExport',state);
        end
        custom=strcmp(lrMarker.Value,'Custom position');
        if strcmp(lrMarker.Value,'Hidden') || (~custom && ~strcmp(currentBackend,'Coronal slice stack'))
            delete(label);return;
        end
        if isempty(label),label=uilabel(renderPanel,'FontColor','w','BackgroundColor','k','FontSize',16,'FontWeight','bold', ...
                'HorizontalAlignment','center','Tag','VolumeOrientationMarker');end
        camera=cameraState();
        if isappdata(fig,'FUSIVolumeMovieCamera')
            movieCamera=getappdata(fig,'FUSIVolumeMovieCamera');
            camera.position=movieCamera.CameraPosition;camera.target=movieCamera.CameraTarget;camera.up=movieCamera.CameraUpVector;
        end
        forward=camera.target-camera.position;right=cross(forward,camera.up);
        names={'L','R'};if strcmp(S.displayLeftRight.columnOneSide,'right'),names=fliplr(names);end
        if right(1)<0,names=fliplr(names);end
        if ~S.displayLeftRight.confirmed,names=cellfun(@(a)[a '?'],names,'UniformOutput',false);end
        label.Text=[names{1} ' ' char(8594) ' ' names{2}];
        panelSize=renderPanel.Position(3:4);
        xy=markerPoint.*panelSize;
        if ~custom && ~isempty(stackObjects) && isgraphics(stackObjects(1))
            object=stackObjects(1);point=[mean(object.XData(:)) max(object.YData(:)) mean(object.ZData(:))];
            forward=forward/norm(forward);right=right/norm(right);up=cross(right,forward);
            rect=surfaceAx.Position;scale=rect(4)/(2*norm(camera.position-camera.target)*tand(camera.angle/2));
            xy=rect(1:2)+rect(3:4)/2+scale*[(point-camera.target)*right' (point-camera.target)*up'];xy(2)=xy(2)-32;
        end
        label.Position=[max(0,min(panelSize(1)-110,xy(1)-55)) max(0,min(panelSize(2)-28,xy(2))) 110 28];
    end
    function layoutLegend()
        if ~isvalid(legendPanel),return;end
        height=max(100,legendPanel.Position(4));width=max(60,legendPanel.Position(3));
        bottom=20;top=height-64;barHeight=max(20,top-bottom);
        legendImage.Position=[6 bottom 18 barHeight];
        legendTitle.Position=[4 height-54 width-8 48];
        for j=1:5
            legendTicks(j).Position=[30 bottom+(j-1)*barHeight/4-12 width-32 24];
        end
    end
    function resizeSurface()
        if ~isempty(surfaceAx) && isvalid(surfaceAx)
            surfaceAx.Position=[65 55 max(100,renderPanel.Position(3)-100) max(100,renderPanel.Position(4)-95)];
            updateDecorations();
        end
    end
    function state=cameraState()
        state=[];
        if ~isempty(renderer) && isvalid(renderer)
            state=struct('position',renderer.CameraPosition,'target',renderer.CameraTarget,'up',renderer.CameraUpVector,'zoom',renderer.CameraZoom);
        elseif ~isempty(surfaceAx) && isvalid(surfaceAx)
            state=struct('position',surfaceAx.CameraPosition,'target',surfaceAx.CameraTarget,'up',surfaceAx.CameraUpVector,'angle',surfaceAx.CameraViewAngle);
        end
    end
    function restoreCamera(state)
        if ~isempty(renderer) && isvalid(renderer) && isfield(state,'zoom')
            renderer.CameraPosition=state.position;renderer.CameraTarget=state.target;renderer.CameraUpVector=state.up;renderer.CameraZoom=state.zoom;
        elseif ~isempty(surfaceAx) && isvalid(surfaceAx) && isfield(state,'angle')
            surfaceAx.CameraPosition=state.position;surfaceAx.CameraTarget=state.target;surfaceAx.CameraUpVector=state.up;surfaceAx.CameraViewAngle=state.angle;
        end
    end
    function resetCamera(~,~)
        if ~isempty(initialCamera),restoreCamera(initialCamera);end
        if ~isempty(renderer) && isvalid(renderer),renderer.Interactions='all';end
        updateDecorations();
    end
    function loadAtlasContext(~,~)
        stopPlayback();
        startFolder=fusiVolumeAtlasTransformFolder(data.par,atlasFile);
        setappdata(fig,'FUSIVolumeAtlasPickerStart',startFolder);
        picker=@uigetfile;if isappdata(fig,'FUSIVolumeAtlasPicker'),picker=getappdata(fig,'FUSIVolumeAtlasPicker');end
        [file,folder]=picker('*.mat','Load reviewed 3D atlas Transformation.mat',fullfile(startFolder,'Transformation.mat'));
        if isequal(file,0),return;end
        installAtlasContext(fullfile(folder,file));
    end
    function installAtlasContext(file)
        if ~isvalid(fig),return;end
        stopPlayback();
        try
            candidate=fusiVolumeAtlasContext(data,file,[],160,atlasContext);
            sameAtlasGrid=~isempty(atlasContext) && ...
                isequal(candidate.spacingYXZmm,atlasContext.spacingYXZmm) && ...
                isequal(size(candidate.reference),size(atlasContext.reference));
            if isstruct(file),currentAtlasTransform=file;
            else
                savedTransform=load(file,'Transf');currentAtlasTransform=savedTransform.Transf;
                fusiAtlasTransformFolder(data.par,file,fileparts(file));atlasFile=file;
            end
            if isempty(atlasContext),nativeDisplayGeometry=struct('spacing',[dy.Value dx.Value dz.Value],'units',unit.Value);end
            atlasContext=candidate;cachedOpt=[];anatomyKey=[];nativeAnatomy=[];
            if ~nativeSideExplicit
                g=candidate.provenance.scanGeometry;side='left';
                if isfield(g,'nativeColumnOneSide'),side=g.nativeColumnOneSide;
                elseif isfield(g,'flipAxes') && ismember(find(g.permutation==2,1),g.flipAxes),side='right';end
                nativeLR.Value=[upper(side(1)) lower(side(2:end))];
            end
            rgbaBackground=[];rgbaBackgroundKey=[];surfaceKey=[];stackDataKey=[];stackDataRows=[];
            % Updating an affine on the same atlas grid only changes the
            % mapped data. Keep the live canvas, interactions and camera;
            % replacing its asynchronous web renderer can leave a blank
            % viewport while old/new camera events are still being queued.
            if ~sameAtlasGrid,geometry=[];initialCamera=[];newBackend('');end
            dy.Value=candidate.spacingYXZmm(1);dx.Value=candidate.spacingYXZmm(2);dz.Value=candidate.spacingYXZmm(3);unit.Value='mm';
            if isstruct(file),atlasNote.Text='Unsaved alignment preview. Use SAVE TRANSFORM in the registration editor to keep it.';
            else,atlasNote.Text=sprintf('%s. Reference tissue outside acquired coverage is atlas anatomy.',file);end
            if candidate.provenance.reviewRequired,atlasNote.Text=[atlasNote.Text ' Automatic proposal: anatomical review is still required.'];end
            if ~sameAtlasGrid,atlasAlpha.Value=80;vessels.Value=false;end
            refresh();
            if ~sameAtlasGrid
                waitRender();alignCamera([],[]);drawnow;
            end
            if candidate.provenance.reviewRequired,status.Text=[status.Text ' This automatic proposal still requires anatomical review.'];end
        catch ME,status.Text=ME.message;end
    end
    function clearAtlasContext(~,~)
        stopPlayback();atlasContext=[];atlasFile='';currentAtlasTransform=[];cachedOpt=[];anatomyKey=[];geometry=[];initialCamera=[];
        dy.Value=nativeDisplayGeometry.spacing(1);dx.Value=nativeDisplayGeometry.spacing(2);dz.Value=nativeDisplayGeometry.spacing(3);unit.Value=nativeDisplayGeometry.units;
        atlasNote.Text='Native acquired field of view. No whole-brain atlas reference.';vessels.Value=true;viewChoice.Value='Coronal';refresh();alignCamera([],[]);
    end
    function adjustAtlasContext(~,~)
        stopPlayback();
        input=currentAtlasTransform;if isempty(input),input=atlasFile;end
        try,fusiVolumeEditAtlasRegistration(data,input,@installAtlasContext,@installAtlasContext);
        catch ME,status.Text=ME.message;end
    end
    function reviewAtlasContext(~,~)
        stopPlayback();
        if isempty(atlasContext) && ~atlasOnly,status.Text='Load a 3D transform before reviewing anatomical planes.';return;end
        state=getappdata(fig,'FUSIVolumeExport');S=getappdata(fig,'FUSIVolumeSnapshot');
        if strcmp(atlasType.Value,'Vascular') && ~atlasOnly,S.atlasReference=atlasContext.vascular;end
        fusiVolumeReviewAtlas(S,state.metadata.settings.display);
    end
    function p=playbackInfo()
        if usesSequence()&&~isempty(sequence)
            if isempty(sequencePlan),sequencePlan=fusiVolumeSequencePlan(sequence);end
            p=sequencePlan;p.frame=find(p.scanIndices==sequence.active&p.localFrames==fr.Value,1);
            if isempty(p.frame),p.frame=1;end
            p.localFrame=fr.Value;p.scanIndex=sequence.active;p.mode=mode.Value;p.FPS=fps.Value;p.sequence=true;return;
        end
        times=(0:nOriginal-1)*data.TR/60;
        frames=find(times>=start.Value-1e-6 & times<=finish.Value+1e-6);
        p=struct('frame',fr.Value,'mode',mode.Value,'frames',frames,'FPS',fps.Value,'timeSec',times(frames)*60,'sequence',false);
    end
    function setFrame(frame)
        if usesSequence()&&~isempty(sequence)
            if isempty(sequencePlan),sequencePlan=fusiVolumeSequencePlan(sequence);end
            index=sequencePlan.scanIndices(frame);local=sequencePlan.localFrames(frame);
            if index~=sequence.active,setVolumeScan(sequence,index,true,true);end
            mode.Value='Frame';fr.Value=local;playShownFrame=frame;refresh();return;
        end
        mode.Value='Frame';fr.Value=frame;refresh();
        playShownFrame=frame;
    end
    function setExportFrame(frame)
        movieRendering=strcmp(currentBackend,'Volume rendering') && ~isempty(vol) && isvalid(vol);
        resetFlag=onCleanup(@finishExportFrame);
        setFrame(frame);
        if isappdata(fig,'FUSIVolumeLastError'),throw(getappdata(fig,'FUSIVolumeLastError'));end
        clear resetFlag;
    end
    function finishExportFrame()
        movieRendering=false;
    end
    function restorePlayback(p)
        if isappdata(fig,'FUSIVolumeMovieVolume'),rmappdata(fig,'FUSIVolumeMovieVolume');end
        if isfield(p,'sequence')&&p.sequence
            if sequence.active~=p.scanIndex,setVolumeScan(sequence,p.scanIndex,true,true);end
            fr.Value=p.localFrame;
        else,fr.Value=p.frame;end
        mode.Value=p.mode;refresh();
    end
    function togglePlayback(~,~)
        if playing,stopPlayback();return;end
        if isappdata(fig,'FUSIVolumeExportBusy'),return;end
        if strcmp(movieKind.Value,'Camera rotation')
            playing=true;play.Text='Pause';playFrames=1:max(2,round(rotationDuration.Value*24));playIndex=1;
            playRate=24;playClock=tic;playCamera=cameraState();startPlaybackTimer();return;
        end
        if strcmp(currentBackend,'Coronal slice stack') && ~isempty(strtrim(stackTimes.Value))
            status.Text='Clear Stack > Time rows to play progressing PSC frames. The current rows show fixed recording times.';return;
        end
        p=playbackInfo();if isempty(p.frames),status.Text='The time interval has no acquired frames.';return;end
        mode.Value='Frame';
        frame=p.frame;if frame<p.frames(1)||frame>=p.frames(end),frame=p.frames(1);end
        setFrame(frame);playing=true;play.Text='Pause';
        playFrames=p.frames;playIndex=find(playFrames>=frame,1);playRate=fps.Value;playClock=tic;playCamera=cameraState();
        playMotionOffset=(playIndex-1)/playRate;
        startPlaybackTimer();
    end
    function startPlaybackTimer()
        if isempty(playTimer) || ~isvalid(playTimer)
            % Leave an event-loop gap after each render. A 50 Hz fixed-rate
            % timer can monopolize MATLAB while the native web volume is
            % still uploading RGB/alpha, making Pause appear unresponsive.
            playTimer=timer('ExecutionMode','fixedSpacing','BusyMode','drop', ...
                'Name','deConfUSIon_volume_playback','Period',playbackPeriod(), ...
                'TimerFcn',@advancePlayback,'ErrorFcn',@playbackError);
        end
        playTimer.Period=playbackPeriod();
        playTimer.start();
    end
    function advancePlayback(~,~)
        if ~isvalid(fig) || busy || ~playing,return;end
        if strcmp(movieKind.Value,'Camera rotation')
            camera=playCamera;elapsed=toc(playClock);
            [camera.position,camera.up]=fusiVolumeCameraMotion(camera.position,camera.target,camera.up,elapsed,motionSettings());
            restoreCamera(camera);updateDecorations();if elapsed>=rotationDuration.Value,stopPlayback();end;return;
        end
        % Keep the requested clock instead of adding rendering time to every
        % frame period. Live display can catch up; movie export never skips.
        elapsed=toc(playClock);motionTime=playMotionOffset+elapsed;
        next=min(numel(playFrames),playIndex+floor(elapsed*playRate));
        if sequenceMovie.Value&&~isempty(sequencePlan)
            % Do not skip an entire scan while disk loading/rendering catches up.
            boundary=find(sequencePlan.scanIndices(playFrames)~=sequence.active & (1:numel(playFrames))>playIndex,1);
            if ~isempty(boundary)&&next>=boundary,next=boundary;end
        end
        if playFrames(next)~=playShownFrame
            oldScan=scanChoice.Value;setFrame(playFrames(next));
            if oldScan~=scanChoice.Value,playIndex=next;playClock=tic;playMotionOffset=motionTime;end
        end
        if strcmp(movieKind.Value,'PSC time series + rotation')&&~isempty(playCamera)
            camera=playCamera;[camera.position,camera.up]=fusiVolumeCameraMotion(camera.position,camera.target,camera.up, ...
                motionTime,motionSettings());restoreCamera(camera);updateDecorations();
        end
        % A scan boundary starts a new clock after loading. Use that clock
        % here so the final scan is not stopped by the preceding scan's time.
        if toc(playClock)>=(numel(playFrames)-playIndex+1)/playRate,stopPlayback();end
    end
    function fpsChanged(~,~)
        if playing
            if strcmp(movieKind.Value,'Camera rotation'),return;end
            stop(playTimer);
            playMotionOffset=playMotionOffset+toc(playClock);
            playIndex=find(playFrames>=playShownFrame,1);playRate=fps.Value;playClock=tic;
            playTimer.Period=playbackPeriod();playTimer.start();
        end
    end
    function seconds=playbackPeriod()
        seconds=round(1000*max(.05,min(.1,1/playRate)))/1000;
    end
    function playbackError(~,event)
        stopPlayback();message='Playback stopped after a rendering error.';
        try,message=[message ' ' event.Data.message];catch,end
        if isvalid(status),status.Text=message;end
    end
    function stopPlayback(varargin)
        playing=false;
        if ~isempty(playTimer) && isvalid(playTimer),stop(playTimer);end
        if isvalid(play),play.Text='Play time series';if strcmp(movieKind.Value,'Camera rotation'),play.Text='Play rotation';end,end
    end
    function cleanupPlayback(~,~)
        if ~isempty(playTimer) && isvalid(playTimer),stop(playTimer);delete(playTimer);end
    end
    function waitRender()
        drawnow;pause(.12);drawnow; % Flush asynchronous legend and viewer updates before capture.
    end
    function value=playbackActive()
        value=playing;
    end
    function exportProgress(done,total,seconds,filename)
        if ~isvalid(fig),return;end
        remaining=NaN;if done>0,remaining=seconds*(total-done)/done;end
        if isfinite(remaining)
            status.Text=sprintf('Exporting %d/%d frames (%.0f%%). About %.0f s remaining.',done,total,100*done/total,remaining);
        else,status.Text=sprintf('Exporting %d frames...',total);end
        status.Tooltip=['Saving to ' filename];drawnow limitrate;
    end
    function exportSelectedMovie(~,~)
        if strcmp(movieKind.Value,'PSC time series'),exportView('time');
        elseif strcmp(movieKind.Value,'PSC time series + rotation'),exportView('combined');else,exportView('mp4');end
    end
    function exportView(kind)
        if ~isappdata(fig,'FUSIVolumeExport'),return;end
        if isappdata(fig,'FUSIVolumeExportBusy'),return;end
        stopPlayback();movieType='rotation';extension=kind;
        if strcmp(kind,'time'),extension='mp4';movieType='timeseries';end
        if strcmp(kind,'combined'),extension='mp4';movieType='combined';end
        png.Enable='off';mp4.Enable='off';timeMovie.Enable='off';play.Enable='off';status.Text='Exporting 3D view...';drawnow;
        try
            if strcmp(extension,'mp4')&&~atlasOnly
                if isappdata(fig,'FUSIVolumeExportRequest')
                    selection=getappdata(fig,'FUSIVolumeExportRequest');rmappdata(fig,'FUSIVolumeExportRequest');
                else
                    currentRange=sscanf(sliceEdit.Value,'%f');currentSlices=currentRange(1):currentRange(end);
                    currentSlices=setdiff(currentSlices,sscanf(excluded.Value,'%f')','stable');
                    initial=num2str(currentSlices);
                    if ~isempty(currentSlices)&&all(diff(currentSlices)==1),initial=sprintf('%d:%d',currentSlices(1),currentSlices(end));end
                    selection=fusiVideoExportDialog(sequence,nZ,initial,data.label,true);
                end
                if isempty(selection),status.Text='Export cancelled.';png.Enable='on';mp4.Enable='on';timeMovie.Enable='on';play.Enable='on';return;end
                chosenSlices=fusiMovieExportSlices(selection.slices,nZ);
                assert(any(strcmp(selection.scope,{'sequence','current'})),'deConfUSIon:VideoExportScope','Choose included scans or the current overlay.');
                setappdata(fig,'FUSIVolumeExportScope',selection.scope);setappdata(fig,'FUSIVolumeExportSlices',chosenSlices);
                selectionGuard=onCleanup(@clearExportSelection); %#ok<NASGU>
                sequencePlan=[];
                if strcmp(selection.scope,'sequence')&&strcmp(movieType,'rotation'),movieType='combined';end
                refresh();
            end
            exportPar=par;exportPar.scanSequence=sequence;
            includeSequence=usesSequence()&&any(strcmp(movieType,{'timeseries','combined'}));
            [filename,identity]=fusiModelExportPath(exportPar,data.label,extension,movieType,includeSequence);
            setappdata(fig,'FUSIVolumeExportIdentity',identity);
            result=fusiExportVolume(fig,filename,max(2,round(rotationDuration.Value*24)),movieType);
            if exist('selectionGuard','var'),clear selectionGuard;end
            if isvalid(fig)
                status.Text=['Export saved: ' result.file];status.Tooltip=sprintf('Saved: %s\nSettings: %s\nCompleted in %.1f seconds.',result.file,result.settingsFile,result.seconds);
                files={result.file};if ~isempty(result.paperFile),files{end+1}=result.paperFile;end
                files{end+1}=result.settingsFile;fusiExportSavedDialog(files,result.seconds);
            end
        catch ME
            if exist('selectionGuard','var'),clear selectionGuard;end
            if isvalid(fig)
                if strcmp(ME.identifier,'deConfUSIon:ProcessingCancelled'),status.Text='Export cancelled. The original view has been restored.';
                else,status.Text=['Export failed: ' ME.message];end
            end
        end
        if isvalid(fig),png.Enable='on';mp4.Enable='on';timeMovie.Enable='on';play.Enable='on';end
    end
    function yes=usesSequence()
        yes=sequenceMovie.Value;
        if isappdata(fig,'FUSIVolumeExportScope'),yes=strcmp(getappdata(fig,'FUSIVolumeExportScope'),'sequence');end
    end
    function clearExportSelection()
        if ~isvalid(fig),return;end
        for name={'FUSIVolumeExportScope','FUSIVolumeExportSlices'},if isappdata(fig,name{1}),rmappdata(fig,name{1});end,end
        sequencePlan=[];refresh();
    end
end

function name=polarityName(mode)
names={'Positive','Negative','Both signs'};name=names{mode};
end
function limits=baselineLimits(data)
limits=[data.baseline.start data.baseline.end];
end
function value=onOff(tf)
if tf,value='on';else,value='off';end
end
function theme(fig)
handles=findall(fig);
for k=1:numel(handles)
    h=handles(k);
    if isprop(h,'FontColor') && startsWith(class(h),'matlab.ui.control.'),h.FontColor=[1 1 1];end
    if isprop(h,'BackgroundColor') && ~isa(h,'matlab.ui.control.Button'),h.BackgroundColor=[0 0 0];end
    if isprop(h,'FontSize') && startsWith(class(h),'matlab.ui.control.'),h.FontSize=14;end
end
end
