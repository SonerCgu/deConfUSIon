function varargout=Motion(action,varargin)
% Motion-artifact workflow selection and physical-time cropping.
switch lower(action)
    case 'choose', varargout{1}=chooseMotionModern(varargin{:});
    case 'chopdialog', varargout{1}=chopDialog(varargin{:});
    case 'chop', [varargout{1:nargout}]=chop(varargin{:});
    otherwise, error('deConfUSIon:MotionAction','Unknown action %s',action);
end
end

function cfg=chopDialog(parent)
cfg=[];
 C=deConfUSIon_ui('palette');
f=figure('Name','Chop data','MenuBar','none','ToolBar','none','NumberTitle','off','Visible','off','Color',C.background);
uicontrol(f,'Style','text','Units','normalized','Position',[.08 .80 .84 .10],'String','Chop data','FontSize',22,'FontWeight','bold','HorizontalAlignment','left','BackgroundColor',C.background,'ForegroundColor',C.text);
uicontrol(f,'Style','text','Units','normalized','Position',[.08 .63 .84 .12],'String','Remove seconds from the beginning and/or end. A new dataset is created and appears in the dataset dropdown.','HorizontalAlignment','left','BackgroundColor',C.background,'ForegroundColor',C.muted);
uicontrol(f,'Style','text','Units','normalized','Position',[.08 .48 .35 .07],'String','Remove from start (s)','HorizontalAlignment','left','BackgroundColor',C.panel,'ForegroundColor',C.text);
a=uicontrol(f,'Style','edit','Units','normalized','Position',[.48 .48 .20 .07],'String','0','Tag','ChopStart','BackgroundColor',C.input,'ForegroundColor',C.text);
uicontrol(f,'Style','text','Units','normalized','Position',[.08 .35 .35 .07],'String','Remove from end (s)','HorizontalAlignment','left','BackgroundColor',C.panel,'ForegroundColor',C.text);
b=uicontrol(f,'Style','edit','Units','normalized','Position',[.48 .35 .20 .07],'String','0','Tag','ChopEnd','BackgroundColor',C.input,'ForegroundColor',C.text);
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.08 .12 .30 .09],'String','CREATE CUT DATASET','BackgroundColor',C.success,'ForegroundColor','w','FontWeight','bold','Callback',@apply);
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.48 .12 .20 .09],'String','CANCEL','BackgroundColor',C.danger,'ForegroundColor','w','FontWeight','bold','Callback',@(~,~)delete(f));
deConfUSIon_ui('present',f,parent); set(f,'Visible','on'); uiwait(f);
    function apply(~,~)
        x=[str2double(a.String) str2double(b.String)];
        if any(~isfinite(x) | x<0) || ~any(x>0), errordlg('Enter nonnegative seconds, with at least one positive cut.'); return; end
        cfg=x; delete(f);
    end
end

function [D,info]=chop(D,startSeconds,endSeconds)
validateattributes(startSeconds,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(endSeconds,{'numeric'},{'scalar','finite','nonnegative'});
T=size(D.I,ndims(D.I)); validateattributes(D.TR,{'numeric'},{'scalar','finite','positive'});
t=(0:T-1)*D.TR;
if isfield(D,'tsec') && numel(D.tsec)==T
    t=double(D.tsec(:).');
    if any(~isfinite(t)) || any(diff(t)<=0), error('deConfUSIon:ChopTiming','Timestamps must increase strictly.'); end
    t=t-t(1);
end
idx=find(t>=startSeconds-1e-9 & t<=t(end)-endSeconds+1e-9);
if numel(idx)<2, error('deConfUSIon:ChopEmpty','The requested cut leaves fewer than two time points.'); end
sourceTime=t; if isfield(D,'sourceTsec') && numel(D.sourceTsec)==T, sourceTime=D.sourceTsec(:).'; end
frameIndex=1:T; if isfield(D,'originalFrameIndices') && numel(D.originalFrameIndices)==T, frameIndex=D.originalFrameIndices(:).'; end
subs=repmat({':'},1,ndims(D.I)); subs{end}=idx; D.I=D.I(subs{:});
invalid={'PSC','I1','bg','baselineFrames','baselineWindowSec','baselineValidMask','frameRateQC_before','frameRateQC_after'};
for k=1:numel(invalid), if isfield(D,invalid{k}), D=rmfield(D,invalid{k}); end, end
if isfield(D,'events'), D.sourceEvents=D.events; D=rmfield(D,'events'); end
for key={'t','time','timestamps'}
    if isfield(D,key{1}) && isnumeric(D.(key{1})) && isvector(D.(key{1})) && numel(D.(key{1}))==T
        D.(key{1})=D.(key{1})(idx);
    end
end
D.sourceTsec=sourceTime(idx); D.originalFrameIndices=frameIndex(idx);
D.tsec=t(idx)-t(idx(1)); D.nVols=numel(idx); D.sampleSpanSec=D.tsec(end);
D.TotalTimeSec=D.nVols*D.TR; D.TotalTimeMin=D.TotalTimeSec/60;
D.totalTime=D.TotalTimeSec; D.totalTimeMin=D.TotalTimeMin;
info=struct('requestedStartSec',startSeconds,'requestedEndSec',endSeconds, ...
    'actualStartSec',t(idx(1)),'actualEndSec',t(end)-t(idx(end)), ...
    'originalFrames',T,'retainedFrames',idx,'timeOriginOffsetSec',sourceTime(idx(1)));
D.chop=info; D.preprocessing=sprintf('Chop data: %.6gs start, %.6gs end',startSeconds,endSeconds);
end
