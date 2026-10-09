function filename=fusiSnapOverlayWorkspace(folder,atlasFile,anatomyFile,contrast)
% ITK-SNAP registry format. Sticky=true displays anatomy ON the atlas.
% This is per-review workspace metadata; no global SNAP preferences change.
if nargin<4,contrast=fusiSnapVesselContrast([]);end
filename=fullfile(folder,'atlas_anatomy_overlay.itksnap');
fid=fopen(filename,'w');assert(fid>=0,'Could not write ITK-SNAP overlay workspace.');
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'<?xml version="1.0" encoding="UTF-8"?>\n<registry>\n');
entry('SaveLocation',strrep(folder,'\','/'));
fprintf(fid,'<folder key="Layers">\n');
layer('Layer[000]',atlasFile,'MainRole','atlas',1,false,false);
layer('Layer[001]',anatomyFile,'OverlayRole','aligned_anatomy',contrast.overlayOpacity,true,true);
fprintf(fid,'</folder>\n</registry>\n');
    function entry(key,value)
        fprintf(fid,'<entry key="%s" value="%s"/>\n',escape(key),escape(value));
    end
    function layer(key,path,role,name,alpha,sticky,hot)
        fprintf(fid,'<folder key="%s">\n',key);
        entry('AbsolutePath',strrep(path,'\','/'));entry('Role',role);
        fprintf(fid,'<folder key="LayerMetaData">\n');
        entry('Alpha',num2str(alpha));entry('Sticky',num2str(sticky));entry('CustomNickName',name);
        if hot
            fprintf(fid,'<folder key="DisplayMapping"><folder key="Curve">\n');
            entry('NumberOfControlPoints','5');
            positions=linspace(0,1,5);window=contrast.normalizedWindow;
            for k=1:5
                fprintf(fid,'<folder key="ControlPoint[%d]">\n',k-1);
                entry('tValue',num2str(window(1)+positions(k)*diff(window),17));
                entry('xValue',num2str(positions(k)^contrast.gamma,17));
                fprintf(fid,'</folder>\n');
            end
            fprintf(fid,'</folder><folder key="ColorMap">\n');
            entry('Preset','Custom');entry('NumberOfControlPoints','5');
            % Hide weak background, then rapidly reveal red/yellow vessels.
            indices=[0 .05 .18 .5 1];rgba=[0 0 0 0;150 0 0 0;255 65 0 200;255 200 20 255;255 255 220 255];
            for k=1:5
                fprintf(fid,'<folder key="ControlPoint[%04d]">\n',k-1);
                entry('Index',num2str(indices(k)));entry('Type','Continuous');
                channels={'R','G','B','A'};
                for side={'Left','Right'}
                    for c=1:4,entry([side{1} '.' channels{c}],num2str(rgba(k,c)));end
                end
                fprintf(fid,'</folder>\n');
            end
            fprintf(fid,'</folder></folder>\n');
        end
        fprintf(fid,'</folder></folder>\n');
    end
end
function value=escape(value)
value=strrep(char(value),'&','&amp;');value=strrep(value,'"','&quot;');
value=strrep(value,'<','&lt;');value=strrep(value,'>','&gt;');
end
