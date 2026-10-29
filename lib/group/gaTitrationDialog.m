function [S,applied]=gaTitrationDialog(S,parent)
% Edit doses without repurposing Group/Condition or changing analysis windows.
applied=false;finished=false;T=S.subj;
if nargin<2,parent=[];end
if isempty(T),errordlg('Add ROI files before assigning concentrations.','Titration');return;end
A=cell(0,2);if isfield(S,'titrationAssignments'),A=S.titrationAssignments;end
data=cell(size(T,1),8);selected=[];unassignedLabel='Not assigned';
for i=1:size(T,1)
    meta=GroupAnalysis_Common('extractRowMetaLight',T(i,:));
    data(i,:)={i,logical(T{i,1}),T{i,2},meta.session,meta.scanID,T{i,3},T{i,4},unassignedLabel};
end
saved=gaTitration('doses',T,S);[doseLabels,doseValues]=gaTitrationDoseChoices();legacyRows=[];
for i=find(isfinite(saved))'
    hit=find(doseValues==saved(i),1);
    if isempty(hit)
        [~,label]=gaTitration('parse',saved(i));data{i,8}=strrep(label,'uM',[char(181) 'M']);
        legacyRows(end+1)=i; %#ok<AGROW>
    else,data{i,8}=doseLabels{hit};end
end
initialLabels=data(:,8);tableChoices=[{unassignedLabel} doseLabels];
bg=[.1 .1 .1];fg=[.95 .95 .95];edit=[.16 .16 .16];
dialogVisible=get(groot,'DefaultFigureVisible');
if ~isempty(parent)&&isgraphics(parent,'figure'),dialogVisible=get(parent,'Visible');end
f=figure('Name','Titration concentrations by animal and scan','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Color',bg,'Position',[150 80 1160 740], ...
    'Visible','off','WindowStyle','normal','CloseRequestFcn',@cancel, ...
    'WindowKeyPressFcn',@onKey,'Tag','GA_TitrationDialog');
cleanup=onCleanup(@()closeDialog(f)); %#ok<NASGU>
uicontrol(f,'Style','text','Units','normalized','Position',[.025 .91 .95 .065], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left','FontSize',11, ...
    'String',{['Choose preset concentrations from 1 pM to 10 ' char(181) 'M for treatment rows. aCSF rows need no concentration.'], ...
    'aCSF is displayed first: one mean per animal across its selected control scans. Source Group/Condition labels are preserved.'});
groups=unique(T(:,3),'stable');groups=groups(~cellfun(@isempty,groups));
uicontrol(f,'Style','text','String','aCSF source Group','Units','normalized','Position',[.025 .85 .15 .035], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
controlGroup=uicontrol(f,'Style','popupmenu','String',[{'Auto'};groups(:)],'Units','normalized', ...
    'Position',[.18 .842 .22 .045],'BackgroundColor',edit,'ForegroundColor',fg,'Tag','GA_TitrationControlGroup', ...
    'Callback',@updateControlConditions);
if isfield(S,'titrationControlGroup'),items=get(controlGroup,'String');v=find(strcmpi(items,S.titrationControlGroup),1);if ~isempty(v),set(controlGroup,'Value',v);end;end
uicontrol(f,'Style','text','String','aCSF Condition','Units','normalized','Position',[.44 .85 .15 .035], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
controlCondition=uicontrol(f,'Style','popupmenu','String',{'Auto'},'Units','normalized', ...
    'Position',[.595 .842 .24 .045],'BackgroundColor',edit,'ForegroundColor',fg,'Tag','GA_TitrationControlCondition');
updateControlConditions([],[]);
if isfield(S,'titrationControlCondition')
    wanted=S.titrationControlCondition;if strcmp(wanted,'<Unspecified>'),wanted='Unspecified';end
    items=get(controlCondition,'String');v=find(strcmpi(items,wanted),1);if ~isempty(v),set(controlCondition,'Value',v);end
end
uicontrol(f,'Style','text','String','Auto chooses aCSF, Vehicle or Control. Multiple control conditions require an explicit choice.', ...
    'Units','normalized','Position',[.025 .79 .95 .035],'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
table=uitable(f,'Units','normalized','Position',[.025 .27 .95 .51],'Data',data, ...
    'ColumnName',{'Row','Use','Animal','Session','Scan','Group','Condition','Concentration'}, ...
    'ColumnEditable',[false false false false false false false true], ...
    'ColumnFormat',{'numeric','logical','char','char','char','char','char',tableChoices}, ...
    'ColumnWidth',{42 40 130 115 130 135 110 145},'RowName',[], ...
    'CellSelectionCallback',@select,'CellEditCallback',@editDose,'FontSize',11,'Tag','GA_TitrationDoseTable');
uicontrol(f,'Style','text','String','Dose for selected rows','Units','normalized', ...
    'Position',[.025 .205 .18 .035],'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
dose=uicontrol(f,'Style','popupmenu','String',doseLabels,'Value',find(strcmp(doseLabels,'100 pM'),1),'Units','normalized', ...
    'Position',[.205 .198 .13 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Tag','GA_TitrationDoseChoice','TooltipString','Choose a fixed concentration preset; custom text entry is disabled.');
uicontrol(f,'Style','pushbutton','String','Assign selected','Units','normalized', ...
    'Position',[.35 .195 .15 .05],'Callback',@assignSelected);
uicontrol(f,'Style','pushbutton','String','Clear selected','Units','normalized', ...
    'Position',[.515 .195 .14 .05],'Callback',@clearSelected);
statusText='Select rows and choose a preset; Concentration cells also use dropdowns.';
if ~isempty(legacyRows),statusText=sprintf('%s %d saved non-preset dose(s) retained until replaced or cleared.',statusText,numel(legacyRows));end
status=uicontrol(f,'Style','text','String',statusText, ...
    'Units','normalized','Position',[.025 .145 .95 .035],'BackgroundColor',bg, ...
    'ForegroundColor',fg,'HorizontalAlignment','left','Tag','GA_TitrationDoseStatus');
uicontrol(f,'Style','text','String','Dose axis','Units','normalized','Position',[.025 .092 .085 .03], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
scale=uicontrol(f,'Style','popupmenu','String',{'Log concentration','Equal spacing'}, ...
    'Units','normalized','Position',[.11 .085 .19 .045],'BackgroundColor',edit,'ForegroundColor',fg,'Value',2,'Tag','GA_TitrationScale');
if isfield(S,'titrationXScale')&&strcmpi(S.titrationXScale,'Log concentration'),set(scale,'Value',1);end
uicontrol(f,'Style','text','String','Error bars','Units','normalized','Position',[.325 .092 .09 .03], ...
    'BackgroundColor',bg,'ForegroundColor',fg,'HorizontalAlignment','left');
errorBand=uicontrol(f,'Style','popupmenu','String',{'SEM','SD','None'}, ...
    'Units','normalized','Position',[.42 .085 .11 .045],'BackgroundColor',edit,'ForegroundColor',fg, ...
    'Value',3,'Tag','GA_TitrationErrorBand','TooltipString','None hides error bars; SEM or SD shows uncertainty across animals.');
if isfield(S,'titrationErrorBand'),v=find(strcmpi(get(errorBand,'String'),S.titrationErrorBand),1);if ~isempty(v),set(errorBand,'Value',v);end;end
showLegend=true;if isfield(S,'titrationShowLegend')&&~isempty(S.titrationShowLegend),showLegend=logical(S.titrationShowLegend);end
legendControl=uicontrol(f,'Style','checkbox','String','Legend','Units','normalized', ...
    'Position',[.54 .087 .085 .04],'Value',double(showLegend),'BackgroundColor',bg,'ForegroundColor',fg, ...
    'Tag','GA_TitrationShowLegend','TooltipString','Show the aCSF/PACAP legend in the top-right corner.');
uicontrol(f,'Style','pushbutton','String','Apply + show titration','Units','normalized', ...
    'Position',[.63 .065 .215 .065],'Callback',@apply,'BackgroundColor',[.22 .7 .52]);
uicontrol(f,'Style','pushbutton','String','Cancel','Units','normalized', ...
    'Position',[.86 .065 .115 .065],'Callback',@cancel);
movegui(f,'center');
set(f,'WindowStyle','modal','Visible',dialogVisible);
if strcmpi(dialogVisible,'on'),figure(f);end
if ~finished&&isgraphics(f),uiwait(f);end
% Nested callbacks can retain the workspace (and onCleanup) after uiwait.
% Always delete explicitly so a surviving modal window cannot block MATLAB.
closeDialog(f);

    function select(~,evt)
        selected=unique(evt.Indices(:,1));
        set(status,'String',sprintf('%d row(s) selected. Concentrations are required for treatment rows; aCSF is pooled within animal.',numel(selected)));
    end
    function editDose(~,evt)
        try
            label=selectedDoseLabel(evt.NewData,evt.Indices(1));if isempty(label),label=unassignedLabel;end
            dt=get(table,'Data');dt{evt.Indices(1),8}=label;set(table,'Data',dt);
        catch ME
            dt=get(table,'Data');dt{evt.Indices(1),8}=evt.PreviousData;set(table,'Data',dt);set(status,'String',ME.message);
        end
    end
    function assignSelected(~,~)
        if isempty(selected),set(status,'String','Select one or more table rows first.');return;end
        try
            items=get(dose,'String');label=selectedDoseLabel(items{get(dose,'Value')},0);
            dt=get(table,'Data');dt(selected,8)={label};set(table,'Data',dt);
            set(status,'String',sprintf('Assigned %s to %d row(s).',label,numel(selected)));
        catch ME,set(status,'String',ME.message);end
    end
    function clearSelected(~,~)
        dt=get(table,'Data');dt(selected,8)={unassignedLabel};set(table,'Data',dt);
    end
    function apply(~,~)
        try
            dt=get(table,'Data');newA=A;
            for j=1:size(T,1)
                label=selectedDoseLabel(dt{j,8},j);
                if isempty(label)&&~isfinite(saved(j)),continue;end
                newA=gaTitration('assign',newA,T,j,label);
            end
            S.titrationAssignments=newA;items=get(scale,'String');S.titrationXScale=items{get(scale,'Value')};
            items=get(errorBand,'String');S.titrationErrorBand=items{get(errorBand,'Value')};
            S.titrationShowLegend=logical(get(legendControl,'Value'));
            items=get(controlGroup,'String');S.titrationControlGroup=items{get(controlGroup,'Value')};
            items=get(controlCondition,'String');S.titrationControlCondition=items{get(controlCondition,'Value')};
            if strcmp(S.titrationControlCondition,'Unspecified'),S.titrationControlCondition='<Unspecified>';end
            S.previewBottomView='Titration';applied=true;finished=true;uiresume(f);
        catch ME,set(status,'String',ME.message);end
    end
    function cancel(~,~),finished=true;uiresume(f);end
    function label=selectedDoseLabel(value,row)
        label=strtrim(char(value));if isempty(label),return;end
        if strcmp(label,unassignedLabel),label='';return;end
        hit=find(strcmp(doseLabels,label),1);
        if ~isempty(hit),label=doseLabels{hit};return;end
        % A legacy dose may stay on its original row, but cannot be newly
        % assigned through a typed value or copied to a different row.
        if row>0&&isfinite(saved(row))&&strcmp(label,initialLabels{row}),return;end
        error('GroupAnalysis:TitrationPreset','Choose a concentration from the preset dropdown (1 pM to 10 micromolar), or clear it.');
    end
    function onKey(~,evt)
        if strcmp(evt.Key,'escape'),cancel([],[]);end
    end
    function updateControlConditions(~,~)
        items=get(controlGroup,'String');chosen=items{get(controlGroup,'Value')};
        if strcmpi(chosen,'Auto')
            for name={'aCSF','Vehicle','Control'},hit=find(strcmpi(groups,name{1}),1);if ~isempty(hit),chosen=groups{hit};break;end;end
        end
        conditions=unique(T(strcmpi(T(:,3),chosen),4),'stable');
        conditions(cellfun(@isempty,conditions))={'Unspecified'};
        set(controlCondition,'String',[{'Auto'};conditions(:)],'Value',1);
    end
end

function closeDialog(f)
if isgraphics(f),delete(f);end
end
