function cfg=chooseMotionModern(parent)
% Modern, compact motion-correction chooser used by the Studio.
% Method-specific panels keep controls aligned and readable at small sizes.
if nargin<1, parent=[]; end
cfg=[]; C=deConfUSIon_ui('palette');
f=figure('Name','Motion correction','NumberTitle','off','MenuBar','none','ToolBar','none', ...
    'Color',C.background,'Visible','off','CloseRequestFcn',@cancel);

uicontrol(f,'Style','text','Units','normalized','Position',[.06 .875 .88 .065], ...
    'String','Motion correction','FontSize',22,'FontWeight','bold','HorizontalAlignment','left', ...
    'BackgroundColor',C.background,'ForegroundColor',C.text);
uicontrol(f,'Style','text','Units','normalized','Position',[.06 .825 .88 .035], ...
    'String','Choose one correction method, set its parameters, then press START. The source dataset is kept unchanged.', ...
    'HorizontalAlignment','left','BackgroundColor',C.background,'ForegroundColor',C.muted);
uicontrol(f,'Style','text','Units','normalized','Position',[.06 .755 .16 .045],'String','METHOD', ...
    'HorizontalAlignment','left','BackgroundColor',C.background,'ForegroundColor',C.cyan,'FontWeight','bold');
methodIndex=1;
methodColors=[C.yellow; C.violet; C.cyan];
hMethodButtons(1)=uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.23 .745 .22 .060], ...
    'String','FRAME REJECTION','UserData',1,'BackgroundColor',methodColors(1,:),'ForegroundColor','w','FontWeight','bold','Callback',@methodChanged);
hMethodButtons(2)=uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.47 .745 .22 .060], ...
    'String','DESPIKING','UserData',2,'BackgroundColor',C.button,'ForegroundColor','w','FontWeight','bold','Callback',@methodChanged);
hMethodButtons(3)=uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.71 .745 .23 .060], ...
    'String','SCRUBBING','UserData',3,'BackgroundColor',C.button,'ForegroundColor','w','FontWeight','bold','Callback',@methodChanged);

pFrame=uipanel(f,'Title','Frame rejection settings','Units','normalized','Position',[.06 .405 .88 .285], ...
    'BackgroundColor',C.panel,'ForegroundColor',C.green,'FontWeight','bold');
label(pFrame,'Detection threshold (sigma)',[.07 .57 .53 .16]);
hSigma=edit(pFrame,'3',[.66 .55 .22 .20]);
label(pFrame,'Direction',[.07 .36 .22 .15]);
hDirection=popup(pFrame,{'Both tails','High only','Low only'},[.30 .335 .28 .21]);
label(pFrame,'Reject frames with global intensity excursions above this threshold.',[.07 .08 .82 .14],C.muted,false);

pDespike=uipanel(f,'Title','Despiking settings','Units','normalized','Position',[.06 .405 .88 .285], ...
    'BackgroundColor',C.panel,'ForegroundColor',C.green,'FontWeight','bold','Visible','off');
label(pDespike,'Robust Z threshold',[.07 .57 .53 .16]);
hZ=edit(pDespike,'5',[.66 .55 .22 .20]);
label(pDespike,'Voxel-wise median/MAD outliers are replaced using a robust threshold.',[.07 .27 .82 .16],C.muted,false);

pScrub=uipanel(f,'Title','Scrubbing settings','Units','normalized','Position',[.06 .405 .88 .285], ...
    'BackgroundColor',C.panel,'ForegroundColor',C.green,'FontWeight','bold','Visible','off');
label(pScrub,'Metric',[.07 .59 .18 .15]);
hMetric=popup(pScrub,{'DVARS','Global Signal'},[.26 .575 .25 .21]);
label(pScrub,'Interpolation',[.55 .59 .20 .15]);
hInterp=popup(pScrub,{'Linear','PCHIP'},[.74 .575 .19 .21]);
hTrim=uicontrol(pScrub,'Style','checkbox','Units','normalized','Position',[.07 .20 .24 .20], ...
    'String','Trim edges','Value',0,'BackgroundColor',C.panel,'ForegroundColor',C.text);
label(pScrub,'Start (s)',[.35 .22 .14 .15]); hStart=edit(pScrub,'0',[.47 .18 .15 .22]);
label(pScrub,'End (s)',[.66 .22 .13 .15]); hEnd=edit(pScrub,'0',[.77 .18 .15 .22]);

hDescription=uicontrol(f,'Style','text','Units','normalized','Position',[.06 .315 .88 .055], ...
    'String','','HorizontalAlignment','left','BackgroundColor',C.background,'ForegroundColor',C.muted);
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.06 .075 .19 .095],'String','HELP', ...
    'BackgroundColor',C.blue,'ForegroundColor','w','FontWeight','bold','Callback',@(~,~)deConfUSIon_ui('help','Motion correction'));
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.58 .075 .21 .095],'String','START', ...
    'BackgroundColor',C.success,'ForegroundColor','w','FontWeight','bold','FontSize',14,'Callback',@start);
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.81 .075 .13 .095],'String','CANCEL', ...
    'BackgroundColor',C.danger,'ForegroundColor','w','FontWeight','bold','Callback',@cancel);

deConfUSIon_ui('present',f,parent);
set([pFrame pDespike pScrub],'ForegroundColor',C.green);
set(f,'Visible','on');
methodChanged(hMethodButtons(1),[]);
setDescription(); uiwait(f);

    function methodChanged(src,~)
        methodIndex=get(src,'UserData'); v=methodIndex;
        set(pFrame,'Visible',onoff(v==1)); set(pDespike,'Visible',onoff(v==2)); set(pScrub,'Visible',onoff(v==3));
        for jj=1:3
            if jj==v, set(hMethodButtons(jj),'BackgroundColor',methodColors(jj,:));
            else, set(hMethodButtons(jj),'BackgroundColor',C.button); end
        end
        setDescription(); drawnow;
    end
    function setDescription()
        v=methodIndex;
        d={'Frame rejection removes complete frames whose global signal exceeds the threshold.', ...
           'Despiking replaces isolated voxel-wise outliers using a robust median/MAD estimate.', ...
           'Scrubbing interpolates high-motion frames; optional edge trimming removes start/end seconds.'};
        set(hDescription,'String',d{v});
    end
    function start(~,~)
        ms={'Frame rejection','Despiking','Scrubbing'}; mi=get(hMetric,'String'); ii=get(hInterp,'String'); dd=get(hDirection,'String'); v=methodIndex;
        cfg=struct('method',ms{v},'frameSigma',str2double(get(hSigma,'String')), ...
            'frameDirection',dd{get(hDirection,'Value')}, ...
            'despikeZ',str2double(get(hZ,'String')),'scrubMetric',mi{get(hMetric,'Value')}, ...
            'scrubInterpolation',ii{get(hInterp,'Value')},'scrubTrim',logical(get(hTrim,'Value')), ...
            'trimStartSec',str2double(get(hStart,'String')),'trimEndSec',str2double(get(hEnd,'String')));
        if ~isfinite(cfg.frameSigma) || cfg.frameSigma<=0 || ~isfinite(cfg.despikeZ) || cfg.despikeZ<=0 || ...
                any(~isfinite([cfg.trimStartSec cfg.trimEndSec])) || any([cfg.trimStartSec cfg.trimEndSec]<0)
            errordlg('Use positive thresholds and nonnegative trim times.','Motion correction'); return;
        end
        delete(f);
    end
    function cancel(~,~), cfg=[]; if ishghandle(f), delete(f); end, end
    function h=edit(p,s,pos), h=uicontrol(p,'Style','edit','Units','normalized','Position',pos,'String',s,'BackgroundColor',C.input,'ForegroundColor',C.text); end
    function h=popup(p,s,pos), h=uicontrol(p,'Style','popupmenu','Units','normalized','Position',pos,'String',s,'Value',1,'BackgroundColor',C.input,'ForegroundColor',C.text); end
    function label(p,s,pos,varargin)
        fg=C.text; bold=true; if ~isempty(varargin), fg=varargin{1}; end; if numel(varargin)>1, bold=varargin{2}; end
        if bold, fw='bold'; else, fw='normal'; end
        uicontrol(p,'Style','text','Units','normalized','Position',pos,'String',s,'HorizontalAlignment','left','BackgroundColor',C.panel,'ForegroundColor',fg,'FontWeight',fw);
    end
    function out=onoff(tf), if tf, out='on'; else, out='off'; end, end
end
