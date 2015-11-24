function fwdBEM = BEM(lambda,force)

if(nargin<2)
    force=false;
end


if(exist('MMC_Collins_Atlas_Mesh_Version_2L.mat')~=2)
    disp('You need to download the MMC Colin atlas');
    disp('Go to:');
    disp('http://mcx.sourceforge.net/cgi-bin/index.cgi?MMC/Colin27AtlasMesh');
    disp('Register, download, and add the file "MMC_Collins_Atlas_Mesh_Version_2L.mat" to the matlab path');
    disp('then rerun this command');
    fwdBEM=[];;
    return
end
        
 % If I already have this file, then just load it
 a=which('nirs.registration.Colin27.BEM');
 folder=fileparts(a); 
 
if(exist(fullfile(folder,'ColinBEM.mat'))==2 && ~force)
    load(fullfile(folder,'ColinBEM.mat'));
    
    prop{1} = nirs.media.tissues.skin(lambda);
    prop{2} = nirs.media.tissues.bone(lambda);
    prop{3} = nirs.media.tissues.water(lambda);
    prop{4} = nirs.media.tissues.brain(0.7, 50,lambda);
    
    fwdBEM.prop  = prop;
    return
end


load MMC_Collins_Atlas_Mesh_Version_2L.mat
% Collins adult brain atlas FEM mesh - Version 2L (low-resolution).
% 
% Created on 02/05/2011 by Qianqian Fang [1] with iso2mesh [2] version 1.0.0.
% The gray/white matter surfaces were created by Katherine Perdue [3] with FreeSurfer [4]
% 
% Please refer to 'Qianqian Fang, "Mesh-based Monte Carlo method using fast ray-tracing in Plucker coordinates," Biomed. Opt. Express 1(1), 165-175 (2010)' for details.
% 
% Format: 
%         node: node coordinates (in mm)
%         face: surface triangles, the last column is the surface ID, 
%                 1-scalp, 2-CSF, 3-gray matter, 4-white matter
%         elem: tetrahedral elements, the last column is the region ID, 
%                 1-scalp and skull layer, 2-CSF, 3-gray matter, 4-white matter 
% URL: http://mcx.sourceforge.net/cgi-bin/index.cgi?MMC/CollinsAtlasMesh

node = node-ones(size(node,1),1)*mean(node,1);

for idx=1:4
    elem_local = elem(find(elem(:,5)==idx),1:4);
    face_local = face(find(face(:,4)==idx),1:3);
    [lst,ia,ib]=unique([elem_local(:); face_local(:)],'stable');
    node_local = node(lst,:);
    lst2=[1:length(lst)];
    elem_local(:)=lst2(ib(1:length(elem_local(:))));
    face_local(:)=lst2(ib(1+length(elem_local(:)):end));
    
    BEM(idx)=nirs.core.Mesh(node_local,face_local,[]);
    BEM(idx)=reducemesh(BEM(idx),.25);
    BEM(idx).transparency=.1;
end
BEM(end).transparency=1;

prop{1} = nirs.media.tissues.skin(lambda);
prop{2} = nirs.media.tissues.bone(lambda);
prop{3} = nirs.media.tissues.water(lambda);
prop{4} = nirs.media.tissues.brain(0.7, 50,lambda);



tbl=nirs.util.list_1020pts('?');
Pos =[tbl.X tbl.Y tbl.Z];

Pos = icbm_spm2tal(Pos);

[TR, TT] = icp(BEM(1).nodes',Pos');
Pos=(TR*Pos'+TT*ones(1,size(Pos,1)))';
% k=dsearchn(BEM(1).nodes,Pos);
% Pos=BEM(1).nodes(k,:);
Pos = projectsurface(Pos,BEM(1).nodes);


fidtbl=table(tbl.Name,Pos(:,1),Pos(:,2),Pos(:,3),repmat({'10-20'},length(tbl.Name),1),...
    repmat({'mm'},length(tbl.Name),1),repmat(true,length(tbl.Name),1),...
    'VariableNames',BEM(1).fiducials.Properties.VariableNames);

if(height(BEM(1).fiducials)==0)
    BEM(1).fiducials=fidtbl;
else
    BEM(1).fiducials=[BEM(1).fiducials; fidtbl];
end

fwdBEM = nirs.forward.NirfastBEM();
fwdBEM.mesh  = BEM;
fwdBEM.prop  = prop;

end


function pos = projectsurface(pos,surf)

com = mean(surf,1);
for idx=1:size(pos,1)
    vec = pos(idx,:)-com;
     c = [0:.1:2*norm(vec)];
    vec=vec/norm(vec);
    p=c'*vec+ones(length(c),1)*com;
    [k,d]=dsearchn(surf,p);
    [~,i]=min(d);
    pos(idx,:)=p(i,:);
end

end