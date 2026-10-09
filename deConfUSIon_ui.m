function varargout=deConfUSIon_ui(action,varargin)
% Shared deConfUSIon presentation and context help, version 2026-09-06.
deConfUSIon_setup();
switch lower(action)
    case 'style', styleFigure(varargin{:});
    case 'identity', identityHeader(varargin{:});
    case 'label', varargout{1}=datasetLabel(varargin{:});
    case 'help', showHelp(varargin{:});
    case 'palette', varargout{1}=palette();
    case 'present', presentFigure(varargin{:});
    case 'liveedit', installLiveEdit(varargin{:});
    case 'datedlabel', varargout{1}=datedLabel(varargin{:});
    case 'progress', varargout{1}=openProgress(varargin{:});
    case 'progressupdate', updateProgress(varargin{:});
    case 'progressclose', closeProgress(varargin{:});
    otherwise, error('deConfUSIon:UIAction','Unknown UI action: %s',action);
end
end

function h=openProgress(titleText,enabled)
if nargin<2, enabled=true; end
h=[]; if ~enabled, return; end
h=waitbar(0,'','Name',[titleText ' progress'], ...
    'CreateCancelBtn',@(b,~)setappdata(ancestor(b,'figure'),'CancelProcessing',true));
set(h,'Tag','deConfUSIonProgress','CloseRequestFcn',@(f,~)setappdata(f,'CancelProcessing',true));
set(h,'Units','pixels'); position=get(h,'Position'); position(3:4)=[540 190]; set(h,'Position',position);
C=palette();
uicontrol(h,'Style','text','Tag','ProcessingStatus','Units','normalized','Position',[.05 .70 .9 .22], ...
    'String','Preparing...','BackgroundColor',C.background,'ForegroundColor',C.text,'FontName','Arial','FontSize',13,'FontWeight','bold','HorizontalAlignment','left');
uicontrol(h,'Style','text','Tag','ProcessingETA','Units','normalized','Position',[.05 .51 .9 .16], ...
    'String','Estimating remaining time...','BackgroundColor',C.background,'ForegroundColor',C.text,'FontName','Arial','FontSize',12,'HorizontalAlignment','left');
set(findall(h,'Type','axes'),'Units','normalized','Position',[.05 .34 .9 .10]);
set(findall(h,'Style','pushbutton'),'Units','normalized','Position',[.72 .06 .23 .19]);
setappdata(h,'deConfUSIonNoMaximize',true);
setappdata(h,'ProgressStarted',tic); setappdata(h,'ProgressUpdated',tic);
setappdata(h,'CancelProcessing',false); presentFigure(h);
end

function updateProgress(h,fraction,stage)
if isempty(h), return; end
if ~isgraphics(h) || isequal(getappdata(h,'CancelProcessing'),true)
    error('deConfUSIon:ProcessingCancelled','Processing cancelled; the input dataset is unchanged.');
end
fraction=min(1,max(0,fraction));
if fraction<1 && toc(getappdata(h,'ProgressUpdated'))<.15, return; end
elapsed=toc(getappdata(h,'ProgressStarted'));
estimate='Estimating remaining time...';
if fraction>=.02 && elapsed>=1
    remaining=elapsed*(1-fraction)/max(eps,fraction);
    estimate=sprintf('Elapsed %s | about %s remaining',durationText(elapsed),durationText(remaining));
end
waitbar(fraction,h,'');
set(findall(h,'Tag','ProcessingStatus'),'String',sprintf('%s  (%d%%)',stage,round(100*fraction)));
set(findall(h,'Tag','ProcessingETA'),'String',estimate);
setappdata(h,'ProgressUpdated',tic); drawnow;
if ~isgraphics(h) || isequal(getappdata(h,'CancelProcessing'),true)
    error('deConfUSIon:ProcessingCancelled','Processing cancelled; the input dataset is unchanged.');
end
end

function s=durationText(seconds)
seconds=max(0,round(seconds));
if seconds<60, s=sprintf('%d s',seconds);
elseif seconds<3600, s=sprintf('%d min %02d s',floor(seconds/60),mod(seconds,60));
else, s=sprintf('%d h %02d min',floor(seconds/3600),floor(mod(seconds,3600)/60)); end
end

function closeProgress(h)
if ~isempty(h) && isgraphics(h), delete(h); end
end

function installLiveEdit(h)
% Native edit controls keep normal mouse selection and Ctrl+A behavior.
for k=1:numel(h)
    set(h(k),'KeyReleaseFcn',@releaseEdit);
end
end

function name=datedLabel(name,D,fallbackFile)
stamp=''; path='';
if nargin<3, fallbackFile=''; end
% Refreshes can run repeatedly while a save is queued. Keep the label stable
% instead of appending the same creation date on every refresh.
hadStamp=~isempty(regexp(char(name),'\|\s*\d{2}/\d{2}/\d{2}(\s|$)','once'));
if hadStamp
    % Keep the date but rebuild the transient queue suffix below so a
    % queued label can change to saved/failed on the next refresh.
    name=regexprep(char(name),'\s+\[(queued|saving|failed)\]$','','ignorecase');
end
if isstruct(D)
    if isfield(D,'datasetSortTime') && isscalar(D.datasetSortTime) && isfinite(D.datasetSortTime) && D.datasetSortTime>500000
        stamp=datestr(D.datasetSortTime,'dd/mm/yy');
    end
    for key={'savedFile','lazyFile','sourceFile','loadedFile'}
        if isfield(D,key{1}) && ischar(D.(key{1})) && exist(D.(key{1}),'file')==2, path=D.(key{1}); break; end
    end
end
if isempty(path), path=fallbackFile; end
if isempty(stamp) && ~isempty(path) && exist(path,'file')==2
    try
        d=System.IO.File.GetCreationTime(path); stamp=char(d.ToString('dd/MM/yy'));
    catch
        d=dir(path); stamp=datestr(d.datenum,'dd/mm/yy');
    end
end
if ~hadStamp && ~isempty(stamp), name=[name ' | ' stamp]; end
if isstruct(D) && isfield(D,'savedFile')
    state=DataIO('status',D.savedFile);
    if any(strcmp(state,{'queued','saving','failed'})), name=[name ' [' state ']']; end
end
end

function releaseEdit(h,event)
key=lower(char(event.Key));
if any(strcmp(key,{'leftarrow','rightarrow','home','end','shift','control','alt','escape','tab','return','enter'})), return; end
s=get(h,'String'); numbers=sscanf(strrep(s,',',' '),'%f');
if any(strcmp(key,{'uparrow','downarrow'}))
    x=str2double(s);
    if isfinite(x)
        step=1; if any(strcmp(event.Modifier,'shift')), step=10; end
        if strcmp(key,'downarrow'), step=-step; end
        set(h,'String',num2str(x+step));
    end
end
if isempty(numbers) || any(~isfinite(numbers)), return; end
cb=get(h,'Callback');
if isa(cb,'function_handle'), cb(h,[]); end
drawnow limitrate nocallbacks;
end

function C=palette()
C=struct('background',[0.055 0.071 0.102],'panel',[0.082 0.106 0.145], ...
    'input',[0.118 0.149 0.192],'text',[0.91 0.94 0.98], ...
    'muted',[0.66 0.74 0.82],'accent',[0.22 0.72 0.78], ...
    'button',[0.14 0.25 0.34],'success',[0.12 0.40 0.32], ...
    'danger',[0.52 0.20 0.24],'green',[0.18 0.64 0.38], ...
    'blue',[0.16 0.40 0.78],'cyan',[0.22 0.72 0.78], ...
    'yellow',[0.82 0.62 0.18],'violet',[0.52 0.34 0.78], ...
    'font','Arial');
end

function styleFigure(fig)
if isempty(fig) || ~ishghandle(fig), return; end
% The volume viewer owns its web layout and pure-black theme.
if strcmp(get(fig,'Tag'),'FUSI_VolumeGUI'),return;end
C=palette(); setappdata(fig,'deConfUSIonOwned',true);
set(fig,'Color',C.background);
panels=findall(fig,'Type','uipanel');
for k=1:numel(panels)
    if isequal(getappdata(panels(k),'PreserveColors'),true), continue; end
    set(panels(k),'BackgroundColor',C.panel,'ForegroundColor',C.text, ...
        'FontName',C.font,'FontSize',12,'FontWeight','bold');
end
ctrl=findall(fig,'Type','uicontrol');
for k=1:numel(ctrl)
    h=ctrl(k); st=get(h,'Style'); label=get(h,'String');
    % Multiline buttons/dialog controls return a character matrix. REGEXP
    % requires a row, so normalize only the styling copy of the label.
    if ischar(label) && size(label,1)>1, label=strjoin(cellstr(label),' '); end
    if isstring(label), label=strjoin(cellstr(label(:)),' '); end
    if isequal(getappdata(h,'PreserveColors'),true), continue; end
    set(h,'FontName',C.font);
    p=getpixelposition(h); fs=get(h,'FontSize');
    if p(4)>=25, fs=max(10,min(13,fs)); else, fs=max(9,min(11,fs)); end
    if strcmp(get(h,'Tag'),'deConfUSIonDatasetHeader'), fs=14; end
    preferred=getappdata(h,'PreferredFontSize');
    if isnumeric(preferred) && isscalar(preferred) && isfinite(preferred), fs=preferred; end
    set(h,'FontSize',fs,'ForegroundColor',C.text);
    switch st
        case {'edit','listbox','popupmenu'}
            set(h,'BackgroundColor',C.input,'FontWeight','normal');
        case 'pushbutton'
            color=C.button;
            if ischar(label)
                low=lower(label);
                if ~isempty(regexp(low,'help|manual','once'))
                    color=[0.12 0.35 0.78];
                elseif strcmp(strtrim(low),'pca')
                    color=[0.16 0.42 0.82];
                elseif strcmp(strtrim(low),'ica')
                    color=[0.12 0.58 0.30];
                elseif ~isempty(regexp(low,'^open(\s|$)|open scm|open video','once'))
                    color=C.success;
                elseif ~isempty(regexp(low,'apply|^run(\s|$)|^automatic.*registration|^continue$|start|compute|proceed|create|save','once'))
                    color=C.success;
                elseif ~isempty(regexp(low,'cancel|stop|close','once'))
                    color=C.danger;
                elseif ~isempty(regexp(low,'undo|reset|settings|options|browse|load|select','once'))
                    color=[0.55 0.38 0.10];
                end
            end
            set(h,'BackgroundColor',color,'FontWeight','bold');
        case {'text','checkbox','radiobutton'}
            parent=get(h,'Parent');
            if isprop(parent,'BackgroundColor'), bg=get(parent,'BackgroundColor'); else, bg=C.background; end
            set(h,'BackgroundColor',bg);
    end
    if ischar(label) && ~isempty(regexp(strtrim(lower(label)),'^(\? ?)?help(\b|$)|^manual$','once')) && strcmp(st,'pushbutton')
        topic=get(fig,'Name');
        set(h,'Callback',@(~,~)deConfUSIon_ui('help',topic), ...
            'TooltipString','Current module help, numerical conventions and full user manual');
    end
end
end

function label=datasetLabel(D,fallback)
if nargin<2, fallback='Dataset'; end
label=''; animal=''; scan='';
if isstruct(D)
    for f={'displayNameFull','preprocDisplayName','loadedName','sourceFile','loadedFile','HUMOR_fullDisplayName'}
        if isfield(D,f{1}) && (ischar(D.(f{1})) || isstring(D.(f{1}))) && ~isempty(D.(f{1}))
            label=char(D.(f{1})); break;
        end
    end
    for f={'animalID','animalId','subjectID'}
        if isfield(D,f{1}) && ~isempty(D.(f{1})), animal=char(string(D.(f{1}))); break; end
    end
    for f={'scanID','scanId','scan'}
        if isfield(D,f{1}) && ~isempty(D.(f{1})), scan=char(string(D.(f{1}))); break; end
    end
end
if isempty(label), label=char(fallback); end
label=strrep(label,'\','/');
if ~isempty(strfind(label,'/')), [~,name,ext]=fileparts(label); label=[name ext]; end
if isempty(animal)
    tok=regexp(label,'(?i)B6J?[_-]+(\d+)','tokens','once');
    if ~isempty(tok), animal=tok{1}; end
end
if isempty(scan)
    tok=regexp(label,'(?i)(scan[_-]?\d+|FUS[_-]?\d+)','match','once');
    if ~isempty(tok), scan=tok; end
end
identity='';
if ~isempty(animal), identity=['Animal ' animal]; end
if ~isempty(scan), identity=[identity ' | ' scan]; end
if ~isempty(identity), label=[identity ' | ' label]; end
end

function identityHeader(fig,D,fallback,method)
label=datasetLabel(D,fallback); C=palette();
set(fig,'Name',[method ' - ' label]);
uicontrol(fig,'Style','text','Units','normalized','Position',[0.03 0.945 0.94 0.045], ...
    'String',label,'Tag','deConfUSIonDatasetHeader','TooltipString',label, ...
    'HorizontalAlignment','left','FontName',C.font,'FontSize',14, ...
    'FontWeight','bold','BackgroundColor',C.background,'ForegroundColor',C.text);
end

function showHelp(topic)
if nargin<1, topic='Overview'; end
C=palette(); root=fileparts(mfilename('fullpath'));
helpFile=fullfile(root,'docs','help_topics.json');
titleText=char(topic);
topicKey='overview';
paragraphs={'Select a dataset, confirm its geometry and timing, and inspect QC before processing.', ...
    'Baseline windows use seconds. PCA/ICA component removal is optional and requires review.', ...
    'Every correction creates a derived dataset. Check its identity before analysis and export.'};
if exist(helpFile,'file')==2
    H=jsondecode(fileread(helpFile));
    paragraphs=cellstr(H.overview);
    keys=fieldnames(H);
    topicKey=lower(strtrim(titleText));
    if ~isempty(strfind(topicKey,'pca')) || ~isempty(strfind(topicKey,'ica')), topicKey='pcaica'; end
    if ~isempty(strfind(topicKey,'scm')) || ~isempty(strfind(topicKey,'signal change')), topicKey='scm'; end
    if ~isempty(strfind(topicKey,'functional connectivity')) || ~strcmp(topicKey,'fc') && ~isempty(strfind(topicKey,'connectivity')), topicKey='fc'; end
    if ~isempty(strfind(topicKey,'standard')), topicKey='standardized'; end
    if ~isempty(strfind(topicKey,'load')), topicKey='load'; end
    if ~isempty(strfind(topicKey,'qc')) || ~isempty(strfind(topicKey,'quality')), topicKey='qc'; end
    if ~isempty(strfind(topicKey,'3d')) && ~isempty(strfind(topicKey,'registration'))
        topicKey='registration_3d';
    elseif ~isempty(strfind(topicKey,'registration')) || ~isempty(strfind(topicKey,'atlas'))
        topicKey='registration';
    end
    if ~isempty(strfind(topicKey,'mask')), topicKey='mask'; end
    if ~isempty(strfind(topicKey,'video')), topicKey='video'; end
    if ~isempty(strfind(topicKey,'time course')) || ~isempty(strfind(topicKey,'time-course')) || ~isempty(strfind(topicKey,'viewer')), topicKey='timecourse'; end
    if ~isempty(strfind(topicKey,'memory')), topicKey='memory'; end
    if ~isempty(strfind(topicKey,'motion')) || ~isempty(strfind(topicKey,'scrub')) || ~isempty(strfind(topicKey,'despik')) || ~isempty(strfind(topicKey,'frame rejection'))
        topicKey='motion_correction';
    end
    if ~isempty(strfind(topicKey,'chop')), topicKey='chop_data'; end
    if ~isempty(strfind(topicKey,'save queue')) || ~isempty(strfind(topicKey,'temporary')) || ~isempty(strfind(topicKey,'tmp'))
        topicKey='save_queue';
    end
    if ~isempty(strfind(topicKey,'atlas region')) || ~isempty(strfind(topicKey,'coarse region')), topicKey='atlas_regions'; end
    if ~isempty(strfind(topicKey,'segment')), topicKey='segmentation'; end
    for k=1:numel(keys)
        if strcmp(keys{k},'overview'), continue; end
        if strcmp(topicKey,lower(keys{k})) || ~isempty(strfind(topicKey,lower(strrep(keys{k},'_',' ')))) || ...
                ~isempty(strfind(lower(titleText),lower(strrep(keys{k},'_',' '))))
            paragraphs=cellstr(H.(keys{k})); break;
        end
    end
end
sections=localHelpSections(topicKey,paragraphs,titleText);
f=figure('Name',['deConfUSIon Help - ' titleText],'NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Color',C.background, ...
    'Units','pixels','Position',[100 60 980 760],'Tag','deConfUSIonHelp');
uicontrol(f,'Style','text','Units','normalized','Position',[.04 .88 .92 .08], ...
    'String',[titleText ' | 2026-09-06'],'HorizontalAlignment','left', ...
    'FontSize',15,'FontWeight','bold','BackgroundColor',C.background,'ForegroundColor',C.text);
% A structured help card is easier to scan than a single undifferentiated
% text box. Each section has a bold heading, wrapped body text, and its own
% color so definitions, mathematics, workflow, and checks are distinguishable.
uicontrol(f,'Style','text','Units','normalized','Position',[.04 .815 .92 .055], ...
    'String',sections{1}.body,'HorizontalAlignment','left','FontSize',12, ...
    'FontAngle','italic','BackgroundColor',C.panel,'ForegroundColor',C.muted);
nBody=numel(sections)-1;
slotH=.115;
for ii=2:numel(sections)
    y=.79-(ii-2)*slotH;
    p=uipanel(f,'Units','normalized','Position',[.04 y-slotH+.008 .92 slotH-.012], ...
        'BackgroundColor',C.panel,'ForegroundColor',C.accent,'BorderType','line');
    uicontrol(p,'Style','text','Units','normalized','Position',[.018 .60 .96 .32], ...
        'String',sections{ii}.title,'HorizontalAlignment','left','FontSize',11, ...
        'FontWeight','bold','BackgroundColor',C.panel,'ForegroundColor',C.accent);
    uicontrol(p,'Style','text','Units','normalized','Position',[.018 .08 .96 .52], ...
        'String',sections{ii}.body,'HorizontalAlignment','left','FontSize',10, ...
        'BackgroundColor',C.panel,'ForegroundColor',C.text);
end
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.04 .04 .43 .08], ...
    'String','Open full user manual','Callback',@(~,~)openManual(root));
uicontrol(f,'Style','pushbutton','Units','normalized','Position',[.53 .04 .43 .08], ...
    'String','Close','Callback',@(~,~)delete(f));
movegui(f,'center'); styleFigure(f);
end

function sections=localHelpSections(topicKey,paragraphs,titleText)
% Return compact, consistently structured help for every module. The first
% item is the italic introduction; subsequent items are numbered cards.
if isempty(paragraphs), paragraphs={['Use ' titleText ' after loading and checking the active dataset.']}; end
intro=char(paragraphs{1});
core=char(strjoin(paragraphs,sprintf(' ')));
definition='This module operates on the active fUSI dataset and keeps the dataset identity, dimensions, and timing attached to its outputs.';
math='The calculation is applied voxel-wise or region-wise to the selected time window; finite values and the recorded TR are preserved.';
workflow=['1) Confirm the active dataset.  2) Choose the displayed parameters.  3) Run the operation.  4) Review the result before saving or exporting.'];
checks='Check the preview, units, baseline/event windows, and output name. Never interpret an output until its orientation and valid-sample count are plausible.';
switch lower(topicKey)
    case 'groupanalysis'
        definition='ROI time courses are aligned on a common time grid. At each time, the mean uses available subjects. SEM = s/sqrt(n), where s is the sample SD and n is the number of finite subject values at that time. SEM requires n >= 2 and is not a confidence interval.';
        math='Plateau = (1/m)*sum(y_i) over a fixed, prespecified interval. It describes mean response, not proof that the curve is flat. Robust peak = max_w TrimMean(y in w): sort the finite samples in each full-duration window and discard floor(m*p/200) from EACH tail, with p the total trim percentage. Default p=10 means 5% per tail. Both metrics require at least 80% of the expected samples and at least two finite values. Peak remains an upward-response metric.';
        workflow='Start with display 0-20 min, plateau 6-9 min and peak search 6-9 min with a 1-min peak window. Change to 10-15 min if your protocol predicts a later response, using the same prespecified rule across groups. Verify baseline separately. Display smoothing affects the drawn curve and band only; metrics use unsmoothed subject traces.';
        checks='Choose windows before comparing groups. Maximizing a peak can bias it upward and wider searches increase this bias. Prefer a fixed plateau mean for a prespecified sustained response. Missing/short recordings may yield NaN metrics. Each input row is a replicate: do not count repeated scans as independent animals. Exports retain the existing metric table and include metric settings in the result structure.';
    case 'psc'
        definition='Percent signal change (PSC) expresses each sample relative to a positive baseline B.';
        math='PSC(t)=100*(S(t)-B)/B. For a new baseline p, SCM rebaselining uses PSCnew=100*(PSC-p)/(100+p).';
    case 'scm'
        definition='SCM (signal change mapping) converts a selected baseline and signal interval into a spatial map and ROI trace.';
        math='For each voxel x, the map is the mean signal in the selected interval after PSC calculation; alpha and thresholding affect display only.';
        workflow='1) Select the mask and baseline. 2) Automatic analysis > Find and review ROI: enter square side length in pixels (4, 8, 15, 25, 50 or custom) and signal start/end in minutes. 3) Search all slices defaults on for motor/matrix stacks; uncheck for the current slice only. 4) Optional positive display sets range 0-30% and alpha modulation 5-10%, without changing scores. 5) Review the ranked candidate table: click a row to navigate to its yellow ROI and trace. Invalid slices are listed as skipped. 6) EXPORT ROIs (TXT) after review; settings and slice IDs are stored in the header. Load fixed protocol remains available for predefined target/control locations.';
        checks='A size of 8 means 8 x 8 pixels, not 8 square millimetres. The entire ROI must fit in the mask with finite samples throughout baseline/signal intervals. Search ignores alpha, thresholds and display smoothing. A maximum selected on the measured response is exploratory and can overestimate effects; use independent localization or fixed protocols for confirmatory comparisons. Nothing is exported automatically in Find and review mode.';
    case 'pcaica'
        definition='PCA finds orthogonal components ordered by explained variance; ICA finds statistically independent source components.';
        math='For centered voxel-by-time X, PCA gives X≈W diag(s) U^T. Explained variance is s_k²/||X||F² using all centered samples. ICA whitens sqrt(T) U^T before symmetric FastICA and reconstructs X≈AS. Removing selected components subtracts their reconstruction and restores the original mean.';
        workflow='1) Open PCA or ICA on raw or processed data. 2) Wait for cancellable decomposition progress. 3) Inspect component traces (and ICA spatial maps). Long recordings use a deterministic randomized PCA basis with two subspace iterations; every frame and voxel participates. The header identifies this approximation and its singular-pair residual. 4) Choose Exact PCA/basis to recompute when needed. 5) Select components and Apply & Close; the named result becomes available in the dataset dropdown.';
        checks='Fast mode starts automatically above 4096 frames; shorter recordings retain exact PCA. The residual measures basis approximation, not anatomical or physiological validity. Weak components can differ from exact PCA. Method, seed and iterations are recorded with applied results. Component sign/order do not establish a source as artifact; inspect the time course and spatial pattern.';
    case 'fc'
        definition='Functional connectivity compares time courses between voxels or regions after the selected preprocessing.';
        math='Pearson r= cov(x,y)/(sd(x)sd(y)); t=r*sqrt((n-2)/(1-r^2)). Multiple tests are controlled with Benjamini-Hochberg FDR.';
    case {'registration','registration_3d'}
        definition='Registration estimates a transform that places the functional volume and atlas/underlay in the same coordinate system.';
        math='Rigid: xregistered=R*x+t. Affine adds scale/shear. 2D automatic refinement maximizes normalized mutual information NMI=(H(F)+H(W))/H(F,W), with entropy H(p)=-sum(p*log(p)); W is the warped source. It searches position, rotation and uniform incremental scale without shear or mirroring. 3D scores several foreground-center positions before Greedy NCC/MI or MATLAB MI refinement. Fitting clips the 1st/99.5th percentiles and applies square-root contrast compression; functional amplitudes remain unchanged.';
        workflow='1) 2D/motor: select a source slice and its approximate coronal atlas plane, then vascular or histology. 2) Click Auto: current atlas plane. Review the proposal, use Undo auto if needed, and explicitly Save Current Slice. Each motor slice retains its own alignment and undo. 3) 3D: select the active mean anatomy, confirm array order and independent voxel spacings, then choose engine, reference and rigid/affine. 4) Run, inspect all planes and slices, then Save reviewed or Undo auto.';
        checks='Use a brain-masked anatomy where available. 2D auto keeps the chosen atlas plane; it does not infer motor spacing or automatically assign atlas slices. 3D can retain a scored starting proposal if the fine fit worsens similarity or coverage, and reports this explicitly. Confirm left/right, ventricles and boundaries: similarity is not anatomical validation. Cancellation preserves the prior alignment. Existing Reg2D and Transformation.mat formats and functional export remain compatible.';
    case 'mask'
        definition='A mask is a binary inclusion function that limits displayed maps, traces, and region summaries.';
        math='M(x)∈{0,1}; a masked mean is mean(S(x,t) for M(x)=1). Painting changes M only and never changes the raw acquisition.';
    case 'motion_correction'
        definition='Motion correction groups frame rejection, robust despiking, and scrubbing so each can create a named derived dataset.';
        math='Robust outliers use median/MAD Z scores; scrubbing can use DVARS, the RMS frame-to-frame change across voxels.';
    case 'filtering'
        definition='Temporal filtering separates slow drift and frequency bands from the measured time course.';
        math='Fs=1/TR. Two-pass IIR/FIR has zero phase and squared magnitude response. FFT masking zeros excluded finite-record frequency bins. Preserving the Doppler mean explicitly retains DC.';
        checks='Choose Butterworth, Chebyshev I/II, elliptic, FIR or FFT in Filtering. IIR/FIR transition bands do not reject everything at the cutoff. FFT can ring at spikes/ends; no low-pass alone can eliminate all motion artifacts. Review Despike/Scrubbing first. Cutoffs must be below the actual Nyquist frequency.';
    case 'timecourse'
        definition='The Time-Course Viewer displays voxel or ROI intensity/PSC values against acquisition time.';
        math='The horizontal coordinate is t_k=k*TR (or recorded tsec when available); averaging is performed only over finite selected voxels.';
    case 'video'
        definition='Video GUI renders each time point as an underlay plus a thresholded functional overlay. For multi-slice data, 3D brain / volume opens a rotatable native-grid view with PNG and rotating MP4 export. Atlas registration is optional for native rendering; anatomical labels require registration.';
        math='The displayed frame is a spatial map at time t_k; color limits and alpha modulation change visualization, not the stored values.';
    case 'load'
        definition='The loader standardizes supported arrays to [Y X T] or [Y X Z T] and records TR, tsec, and voxel geometry.';
        math='For matrix probes the canonical order is [DV LR AP T]; voxelSize supplies the physical aspect used by viewers.';
    case 'segmentation'
        definition='Segmentation extracts one time course per atlas label from registered functional data. Detailed labels can be combined into coarse anatomical families without changing the atlas volume.';
        math='For region r, the trace is S_r(t)=mean{S(x,t): label(x)=r}; coarse families use voxel-count weighted means across member labels.';
    otherwise
        definition=['This panel explains the purpose and assumptions of ' titleText '.'];
end
sections={struct('title','Introduction','body',intro), ...
    struct('title','1. Definition and purpose','body',definition), ...
    struct('title','2. Mathematical concept','body',math), ...
    struct('title','3. How to use it','body',workflow), ...
    struct('title','4. Review and interpretation','body',checks)};
end

function openManual(root)
manual=fullfile(root,'docs','deConfUSIon_User_Manual_2026-09-06.html');
if exist(manual,'file')~=2
    manual=fullfile(root,'docs','deConfUSIon_User_Manual_2026-09-06.pdf');
end
web(manual,'-browser');
end

function presentFigure(f,parent)
% Size once, on the owning Studio's monitor; never poll or move user windows.
if isempty(f) || ~isgraphics(f,'figure'), return; end
if nargin<2 || isempty(parent)
    parent=getappdata(0,'deConfUSIonMainFigure');
end
if isempty(parent) || ~isgraphics(parent,'figure'), parent=f; end
if ~isappdata(f,'deConfUSIonPresented')
    styleFigure(f);
    setappdata(f,'deConfUSIonPresented',true);
    setappdata(f,'deConfUSIonParent',parent);
    try
        id=sprintf('MATLAB %d',feature('getpid'));
    catch
        id='MATLAB';
    end
    if parent~=f
        D=guidata(parent);
        if isstruct(D) && isfield(D,'loadedName') && ~isempty(D.loadedName)
            id=[D.loadedName ' | ' id];
        end
    end
    name=get(f,'Name');
    if isempty(strfind(name,'MATLAB ')), set(f,'Name',[name ' | ' id]); end
end
old=get(parent,'Units'); set(parent,'Units','pixels'); p=get(parent,'Position'); set(parent,'Units',old);
screens=get(0,'MonitorPositions'); center=p(1:2)+p(3:4)/2;
i=find(center(1)>=screens(:,1) & center(1)<screens(:,1)+screens(:,3) & ...
    center(2)>=screens(:,2) & center(2)<screens(:,2)+screens(:,4),1);
if isempty(i), i=1; end
screen=screens(i,:);
set(f,'Units','pixels','Resize','on');
try, set(f,'WindowState','normal'); catch, end
noMax=isappdata(f,'deConfUSIonNoMaximize') && logical(getappdata(f,'deConfUSIonNoMaximize'));
if noMax
    q=get(f,'Position'); q(1)=screen(1)+max(20,round((screen(3)-q(3))/2)); q(2)=screen(2)+max(40,round((screen(4)-q(4))/2)); set(f,'Position',q);
    return;
end
set(f,'Position',[screen(1)+8 screen(2)+48 screen(3)-16 screen(4)-88]);
if strcmp(get(f,'WindowStyle'),'normal')
    try, set(f,'WindowState','maximized'); catch, end
end
end
