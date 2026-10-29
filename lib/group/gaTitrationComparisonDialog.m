function [S,applied]=gaTitrationComparisonDialog(D,S,parent)
% Choose animal-level comparisons between the exact plotted categories.
% Draft edits are committed only on Apply. Stable keys retain saved choices.
applied=false;finished=false;
if nargin<3,parent=[];end
categories=readField(D,'categories',struct([]));
saved=readField(S,'titrationComparisons',struct([]));
if ~isstruct(categories)||(~isempty(categories)&&~all(isfield(categories,{'key','label','doseM'})))
    errordlg('Assign concentrations and prepare the titration plot first.','Titration comparisons');return;
end
if ~isstruct(saved),saved=struct([]);end
if numel(categories)<2&&isempty(saved)
    errordlg('At least two plotted categories are needed. Assign concentrations and an aCSF group first.', ...
        'Titration comparisons');return;
end

tests={'Paired t-test','Welch t-test','Student t-test'};
tails={'both','right','left'};
specs=gaTitrationComparisonSpecs(D,S);

bg=[.10 .10 .10];fg=[.95 .95 .95];edit=[.16 .16 .16];
dialogVisible=get(groot,'DefaultFigureVisible');
if ~isempty(parent)&&isgraphics(parent,'figure'),dialogVisible=get(parent,'Visible');end
f=figure('Name','Titration comparisons and p-values','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Color',bg,'Position',[110 100 1390 780], ...
    'Visible','off','WindowStyle','normal','CloseRequestFcn',@cancel, ...
    'WindowKeyPressFcn',@onKey,'Tag','GA_TitrationComparisonDialog');
guard=onCleanup(@()closeDialog(f)); %#ok<NASGU>
uicontrol(f,'Style','text','Units','normalized','Position',[.025 .895 .95 .082], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',11, ...
    'String',{'Default: unpaired Student t-test, one-tailed dose > aCSF, with unadjusted p-values. Each dot is one animal mean.', ...
    'Use the controls below to change checked tests, or edit rows individually. Paired tests are used only if you select them.', ...
    'Tail: both = two-sided; right = Left > Right; left = Left < Right. Select a row to read its full status.'});

table=uitable(f,'Units','normalized','Position',[.025 .435 .95 .445], ...
    'Data',buildTable(specs,categories),'RowName',[], ...
    'ColumnName',{'Use','Left category','Right category','Test','Tail','n Left','n Right','Pairs','p raw','p adjusted','Status'}, ...
    'ColumnEditable',[true false false true true false false false false false false], ...
    'ColumnFormat',{'logical','char','char',tests,tails,'numeric','numeric','numeric','char','char','char'}, ...
    'ColumnWidth',{38 150 150 145 65 48 48 48 85 85 320}, ...
    'FontSize',11,'Tag','GA_TitrationComparisonTable', ...
    'CellEditCallback',@onTableEdit,'CellSelectionCallback',@onTableSelection);

uicontrol(f,'Style','text','String','Test','Units','normalized','Position',[.025 .366 .065 .027], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
defaultTest=uicontrol(f,'Style','popupmenu','String',{'Student t-test','Welch t-test','Paired t-test'}, ...
    'Units','normalized','Position',[.09 .355 .19 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationDefaultTest','Callback',@applyTestDefaults);
uicontrol(f,'Style','text','String','Tail','Units','normalized','Position',[.30 .366 .045 .027], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
defaultTail=uicontrol(f,'Style','popupmenu', ...
    'String',{'One-tailed: Left > Right','Two-sided','One-tailed: Left < Right'}, ...
    'Units','normalized','Position',[.35 .355 .245 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationDefaultTail','Callback',@applyTestDefaults);
selected=find([specs.show]);
if ~isempty(selected)
    setPopup(defaultTest,specs(selected(1)).test);
    tailChoices={'right','both','left'};v=find(strcmp(tailChoices,specs(selected(1)).tail),1);
    if ~isempty(v),set(defaultTail,'Value',v);end
end
uicontrol(f,'Style','pushbutton','String','Use test + tail','Units','normalized', ...
    'Position',[.61 .35 .155 .055],'Callback',@applyTestDefaults,'Tag','GA_TitrationApplyDefaults');
uicontrol(f,'Style','pushbutton','String','Student vs aCSF','Units','normalized', ...
    'Position',[.78 .35 .195 .055],'Callback',@studentControlPreset,'Tag','GA_TitrationStudentControl');
uicontrol(f,'Style','text','String','Changes update checked rows. Student vs aCSF restores unpaired, one-tailed tests and unadjusted p-values.', ...
    'Units','normalized','Position',[.025 .313 .95 .027], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',10);

uicontrol(f,'Style','pushbutton','String','Add comparisons vs aCSF','Units','normalized', ...
    'Position',[.025 .255 .235 .05],'Callback',@(~,~)preset('control'), ...
    'Tag','GA_TitrationSelectControl');
uicontrol(f,'Style','pushbutton','String','Add adjacent doses','Units','normalized', ...
    'Position',[.275 .255 .215 .05],'Callback',@(~,~)preset('adjacent'), ...
    'Tag','GA_TitrationSelectAdjacent');
uicontrol(f,'Style','pushbutton','String','Add all dose pairs','Units','normalized', ...
    'Position',[.505 .255 .215 .05],'Callback',@(~,~)preset('doses'), ...
    'Tag','GA_TitrationSelectAllDoses');
uicontrol(f,'Style','pushbutton','String','Clear all','Units','normalized', ...
    'Position',[.735 .255 .115 .05],'Callback',@(~,~)preset('clear'), ...
    'Tag','GA_TitrationClearComparisons');
uicontrol(f,'Style','text','String','Presets add to your current selection. Dose presets stay within Group and Condition.', ...
    'Units','normalized','Position',[.025 .218 .95 .027], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',10);

uicontrol(f,'Style','text','String','Correction','Units','normalized','Position',[.025 .169 .078 .028], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
correction=uicontrol(f,'Style','popupmenu','String',{'Holm','Bonferroni','None'}, ...
    'Units','normalized','Position',[.105 .158 .13 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationCorrection','Callback',@recompute);
setPopup(correction,readField(S,'titrationCorrection','None'));
uicontrol(f,'Style','text','String','Alpha','Units','normalized','Position',[.255 .169 .045 .028], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
alpha=uicontrol(f,'Style','edit','String',num2str(readField(S,'titrationAlpha',readField(S,'alpha',.05))), ...
    'Units','normalized','Position',[.305 .158 .065 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationAlpha','Callback',@recompute);
showP=uicontrol(f,'Style','checkbox','String','Show comparisons on graph', ...
    'Units','normalized','Position',[.395 .156 .235 .048],'BackgroundColor',bg,'ForegroundColor',fg, ...
    'Value',double(asLogical(readField(S,'titrationShowP',true))), ...
    'Tag','GA_TitrationShowP','Callback',@recompute);
uicontrol(f,'Style','text','String','Labels','Units','normalized','Position',[.655 .169 .052 .028], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
displayP=uicontrol(f,'Style','popupmenu','String',{'Both','Stars'}, ...
    'Units','normalized','Position',[.71 .158 .13 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationPDisplay','Callback',@recompute);
setPopup(displayP,readField(S,'titrationPDisplay','Both'));

detail=uicontrol(f,'Style','text','String','','Units','normalized', ...
    'Position',[.025 .035 .61 .105],'BackgroundColor',bg,'ForegroundColor',fg, ...
    'FontSize',10,'HorizontalAlignment','left','Tag','GA_TitrationComparisonDetail');
applyButton=uicontrol(f,'Style','pushbutton','String','Apply comparisons','Units','normalized', ...
    'Position',[.665 .055 .19 .065],'BackgroundColor',[.22 .70 .52], ...
    'Callback',@apply,'Tag','GA_TitrationComparisonApply');
uicontrol(f,'Style','pushbutton','String','Cancel','Units','normalized', ...
    'Position',[.87 .055 .105 .065],'Callback',@cancel,'Tag','GA_TitrationComparisonCancel');

preview=struct();selectedRow=[];validSettings=false;recompute();
movegui(f,'center');
set(f,'WindowStyle','modal','Visible',dialogVisible);
if strcmpi(dialogVisible,'on'),figure(f);end
if ~finished&&isgraphics(f),uiwait(f);end
% Do not rely on onCleanup: nested callbacks can keep its workspace alive.
closeDialog(f);

    function onTableEdit(~,evt)
        row=evt.Indices(1);column=evt.Indices(2);
        if column==1,specs(row).show=asLogical(evt.NewData);
        elseif column==4,specs(row).test=canonical(evt.NewData,tests,'Student t-test');
        elseif column==5,specs(row).tail=canonical(evt.NewData,tails,'right');end
        selectedRow=row;recompute();
    end
    function onTableSelection(~,evt)
        if isempty(evt.Indices),selectedRow=[];else,selectedRow=evt.Indices(1,1);end
        updateDetail();
    end
    function syncTableDraft()
        % Read the final visible cell values as well as callback state. This
        % also commits a last dropdown edit when Apply is clicked directly.
        data=get(table,'Data');
        for row=1:min(size(data,1),numel(specs))
            specs(row).show=asLogical(data{row,1});
            specs(row).test=canonical(data{row,4},tests,'Student t-test');
            specs(row).tail=canonical(data{row,5},tails,'right');
        end
    end
    function applyTestDefaults(varargin) %#ok<INUSD>
        syncTableDraft();rows=find([specs.show]);if isempty(rows),rows=1:numel(specs);end
        tailChoices={'right','both','left'};test=popupText(defaultTest);tail=tailChoices{get(defaultTail,'Value')};
        for row=rows,specs(row).test=test;specs(row).tail=tail;end
        selectedRow=[];recompute();
    end
    function studentControlPreset(~,~)
        syncTableDraft();
        for row=1:numel(specs)
            a=find(strcmp({categories.key},specs(row).left),1);
            b=find(strcmp({categories.key},specs(row).right),1);
            specs(row).show=~isempty(a)&&~isempty(b)&&xor(isfinite(categories(a).doseM),isfinite(categories(b).doseM));
            if specs(row).show
                if ~isfinite(categories(a).doseM)
                    old=specs(row).left;specs(row).left=specs(row).right;specs(row).right=old;
                end
                specs(row).test='Student t-test';specs(row).tail='right';
            end
        end
        set(defaultTest,'Value',1);set(defaultTail,'Value',1);setPopup(correction,'None');
        set(showP,'Value',1);setPopup(displayP,'Both');selectedRow=[];recompute();
    end
    function preset(kind)
        for row=1:numel(specs)
            if strcmp(kind,'clear'),specs(row).show=false;continue;end
            a=find(strcmp({categories.key},specs(row).left),1);
            b=find(strcmp({categories.key},specs(row).right),1);
            if isempty(a)||isempty(b),continue;end
            da=categories(a).doseM;db=categories(b).doseM;
            if strcmp(kind,'control')
                choose=xor(isfinite(da),isfinite(db));
            else
                choose=isfinite(da)&&isfinite(db)&&da~=db&&sameStratum(categories(a),categories(b));
                if choose&&strcmp(kind,'adjacent')
                    between=false;
                    for k=1:numel(categories)
                        if sameStratum(categories(a),categories(k))&&isfinite(categories(k).doseM)&& ...
                                categories(k).doseM>min(da,db)&&categories(k).doseM<max(da,db)
                            between=true;break;
                        end
                    end
                    choose=~between;
                end
            end
            if choose,specs(row).show=true;end
        end
        selectedRow=[];recompute();
    end
    function settings=draftSettings()
        settings=S;settings.titrationComparisons=specs;
        settings.titrationCorrection=popupText(correction);
        settings.titrationPDisplay=popupText(displayP);
        settings.titrationShowP=logical(get(showP,'Value'));
        settings.titrationAlpha=str2double(get(alpha,'String'));
        settings.alpha=settings.titrationAlpha;
    end
    function recompute(varargin) %#ok<INUSD>
        validSettings=false;data=buildTable(specs,categories);
        try
            settings=draftSettings();preview=gaTitrationComparisons(D,settings);
            resultRows=readField(preview,'comparisons',struct([]));
            for row=1:numel(specs)
                if ~specs(row).show,continue;end
                match=find(arrayfun(@(x)strcmp(readField(x,'leftKey',''),specs(row).left)&& ...
                    strcmp(readField(x,'rightKey',''),specs(row).right),resultRows),1);
                if isempty(match),data{row,11}='Selected; result unavailable';continue;end
                result=resultRows(match);
                data{row,6}=readField(result,'nLeft',NaN);data{row,7}=readField(result,'nRight',NaN);
                data{row,8}=readField(result,'nPairs',NaN);
                data{row,9}=pNumber(readField(result,'pRaw',NaN));
                data{row,10}=pNumber(readField(result,'pAdjusted',NaN));
                data{row,11}=char(readField(result,'status','Unavailable'));
            end
            validSettings=true;set(applyButton,'Enable','on');
        catch ME
            preview=struct('error',ME.message);set(applyButton,'Enable','off');
        end
        set(table,'Data',data);updateDetail();
    end
    function updateDetail()
        if ~validSettings,showDetail(readField(preview,'error','Invalid comparison settings.'));return;end
        base=sprintf('%d selected comparison(s); %d computable; %s correction. Hiding graph labels does not change the checked test family.', ...
            readField(preview,'familySize',sum([specs.show])),readField(preview,'nComputed',0),popupText(correction));
        if isempty(selectedRow)||selectedRow>numel(specs)
            note='Student and Welch use independent-sample formulas; pairing is never inferred automatically.';
            resultRows=readField(preview,'comparisons',struct([]));
            hasOverlap=arrayfun(@(r)~strcmp(r.test,'Paired t-test')&&~isempty(r.overlappingIDs),resultRows);
            if any(hasOverlap),note=[note ' Matching animal IDs occur across samples; these results retain the independent-sample assumption.'];end
            showDetail({base,note});return;
        end
        request=specs(selectedRow);
        if ~request.show,showDetail({base,'This comparison is not selected. Check Use to compute it.'});return;end
        resultRows=readField(preview,'comparisons',struct([]));
        match=find(arrayfun(@(x)strcmp(readField(x,'leftKey',''),request.left)&& ...
            strcmp(readField(x,'rightKey',''),request.right),resultRows),1);
        if isempty(match),showDetail({base,'Selected comparison result is unavailable.'});return;end
        result=resultRows(match);warningText=char(readField(result,'warning',''));
        alternative=char(readField(result,'alternative',[categoryLabel(categories,request.left) ' versus ' categoryLabel(categories,request.right)]));
        message=sprintf('%s | %s | n Left=%g, n Right=%g, matched=%g. %s', ...
            alternative,readField(result,'test',request.test),readField(result,'nLeft',NaN), ...
            readField(result,'nRight',NaN),readField(result,'nPairs',NaN),warningText);
        showDetail({base,message});
    end
    function showDetail(lines)
        try,lines=textwrap(detail,lines);catch,end
        set(detail,'String',lines);
    end
    function apply(~,~)
        syncTableDraft();
        recompute();if ~validSettings,return;end
        draft=draftSettings();
        for name={'titrationComparisons','titrationCorrection','titrationPDisplay','titrationShowP','titrationAlpha'}
            S.(name{1})=draft.(name{1});
        end
        applied=true;finished=true;uiresume(f);
    end
    function cancel(~,~),finished=true;uiresume(f);end
    function onKey(~,evt)
        if strcmp(evt.Key,'escape'),cancel([],[]);end
    end
end

function data=buildTable(specs,categories)
data=cell(numel(specs),11);
for i=1:numel(specs)
    data(i,:)={logical(specs(i).show),categoryLabel(categories,specs(i).left), ...
        categoryLabel(categories,specs(i).right),specs(i).test,specs(i).tail,NaN,NaN,NaN,'','', 'Not selected'};
end
end

function label=categoryLabel(categories,key)
hit=find(strcmp({categories.key},key),1);
if isempty(hit),label=[char(key) ' (unavailable)'];else,label=char(categories(hit).label);end
end

function match=sameStratum(a,b)
match=strcmpi(strtrim(char(readField(a,'group',''))),strtrim(char(readField(b,'group',''))))&& ...
    strcmpi(strtrim(char(readField(a,'condition',''))),strtrim(char(readField(b,'condition',''))));
end

function out=readField(S,name,fallback)
out=fallback;if isstruct(S)&&isfield(S,name)&&~isempty(S.(name)),out=S.(name);end
end

function value=canonical(value,choices,fallback)
value=char(value);hit=find(strcmpi(value,choices),1);
if isempty(hit),value=fallback;else,value=choices{hit};end
end

function setPopup(control,value)
items=get(control,'String');hit=find(strcmpi(char(value),items),1);
if ~isempty(hit),set(control,'Value',hit);end
end

function value=popupText(control)
items=get(control,'String');value=items{get(control,'Value')};
end

function text=pNumber(p)
if isnumeric(p)&&isscalar(p)&&isfinite(p)&&p>=0&&p<=1,text=sprintf('%.6g',p);else,text='N/A';end
end

function value=asLogical(value)
if ischar(value)||isstring(value),value=any(strcmpi(strtrim(char(value)),{'true','1','yes','on'}));
else,value=isscalar(value)&&~isempty(value)&&isfinite(value)&&logical(value);end
end

function closeDialog(f)
if isgraphics(f),delete(f);end
end
