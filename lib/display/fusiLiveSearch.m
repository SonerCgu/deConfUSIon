function fusiLiveSearch(h,changed)
% Classic edits commit String on focus loss. Track key events for live search.
state=struct('query',char(h.String),'caret',numel(char(h.String)),'selected',false,'before','','pending','');
setappdata(h,'FUSILiveSearchState',state);
set(h,'Callback',@committed,'KeyPressFcn',@press,'KeyReleaseFcn',@released);
    function committed(~,~)
        s=getappdata(h,'FUSILiveSearchState');s.query=char(h.String);s.caret=numel(s.query);s.selected=false;
        setappdata(h,'FUSILiveSearchState',s);changed(s.query);
    end
    function press(~,ev)
        s=getappdata(h,'FUSILiveSearchState');s.before=char(h.String);
        key=char(ev.Key);mods=ev.Modifier;ctrl=any(strcmp(mods,'control'))||any(strcmp(mods,'command'));
        if ctrl&&strcmp(key,'a'),s.selected=true;
        elseif ctrl&&strcmp(key,'v')
            c=clipboard('paste');if s.selected,s.query='';s.caret=0;end
            s.query=[s.query(1:s.caret) c s.query(s.caret+1:end)];s.caret=s.caret+numel(c);s.selected=false;
        elseif ctrl&&strcmp(key,'x')&&s.selected,s.query='';s.caret=0;s.selected=false;
        elseif strcmp(key,'leftarrow'),s.caret=max(0,s.caret-1);s.selected=false;
        elseif strcmp(key,'rightarrow'),s.caret=min(numel(s.query),s.caret+1);s.selected=false;
        elseif strcmp(key,'home'),s.caret=0;s.selected=false;
        elseif strcmp(key,'end'),s.caret=numel(s.query);s.selected=false;
        elseif any(strcmp(key,{'backspace','delete'}))
            if s.selected,s.query='';s.caret=0;
            elseif strcmp(key,'backspace')&&s.caret>0,s.query(s.caret)=[];s.caret=s.caret-1;
            elseif strcmp(key,'delete')&&s.caret<numel(s.query),s.query(s.caret+1)=[];end
            s.selected=false;
        elseif ~ctrl&&~isempty(ev.Character)&&~any(strcmp(key,{'return','enter','tab','escape'}))
            if s.selected,s.query='';s.caret=0;end
            c=char(ev.Character);s.query=[s.query(1:s.caret) c s.query(s.caret+1:end)];s.caret=s.caret+numel(c);s.selected=false;
        end
        s.pending=s.query;setappdata(h,'FUSILiveSearchState',s);
    end
    function released(~,~)
        s=getappdata(h,'FUSILiveSearchState');native=char(h.String);
        if ~strcmp(native,s.before),s.query=native;s.caret=numel(native);end
        setappdata(h,'FUSILiveSearchState',s);changed(s.query);
    end
end
