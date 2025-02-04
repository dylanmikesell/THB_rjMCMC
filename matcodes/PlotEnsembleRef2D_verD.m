% Transdimensional Hierarchical Bayesian (THB) framework with reversible-jump 
% Markov Chain Monte Carlo (rjMCMC) code for seismic refraction
% 
% Descreiption:
%         Please find the user guide for more details
%         
% Please cite this code as: Huang, M.-H., Hudson-Rasmussen, B., Burdick, S., 
% Lekic, V., Nelson, M.D., Fauria, K.E., and Schmerr, N., (2020), Bayesian 
% seismic refraction inversion for critical zone science and near-surface 
% applications, submitted to Geochem. Geophys. Geosys.
%     
% Authors: Mong-Han Huang (mhhuang@umd.edu)
%          Scott Burdick (sburdick@wayne.edu)
%          Vedran Lekic (ved@umd.edu)
%          Berit Hudson-Rasmussen (hudsonb@umd.edu)
% 
% Date: 11 Oct, 2020
%        2 Mar, 2021 (add raypath density & coefficient of variations plots)

%%
set(0,'defaultaxesfontsize',14)

% Add subdirectory to matlab path
addpath(genpath('./matcodes/'))

% Add fast marching toolbox location to matlab path
addpath(genpath('~/Documents/MATLAB/toolbox_fast_marching')) 
addpath(genpath('~/Documents/MATLAB/FACS'))  % for scattered plot
addpath(genpath('~/Documents/MATLAB/crameri_v1.05')) % for color scale

figfolder = ['./models/' fname '/figures/'];
if ~exist(figfolder, 'dir')
    mkdir(figfolder);
end

%ipro = 1;
%pronum = num2str(ipro); % this variable is captured in the "..._params.mat" file

% Load ensemble and parameters
load(['./models/' fname '/' fname '_Final_2D_ensemble.mat'],'X') % verD update to re-order the file loading sequence
load(['./models/' fname '/' fname '_2D_grid.mat'],'Xg','Zg','ElevFMM')

%%
clear model
% remove ensembles before burn-in
X_tmp = X;
X_tmp(1:burn) = [];
E_tmp = [X_tmp.E0];

% sort by E0 and only keep the top 90%
[~,id] = sort(E_tmp);
X0 = X_tmp(id(1:fix(length(id)*.9)));

% Create error function, layer number vectors
E = [X.E];
E0 = [X.E0];
xsig = [X.xsig];
Nuclei = [X.Nuclei];

Nens = length(E); % number of models in ensemble
[Nz,Nx]=size(Zg);

% Initialize parameters for running mean and variance calc
Wmean = 0;
Wvar = 0;
dWmean_o = 0;
dWvar = 0;

% Colorbar with topo
cc = [1 1 1; crameri('roma')];
cstd = [1 1 1; crameri('lajolla')];
ccc = [1 1 1;(parula(1024))];

% Initialize counter
cnt = 1;

for ii=1:length(X0)
    
    model.xx = X0(ii).xx;
    model.zz = X0(ii).zz;
    model.v1D = X0(ii).v1D;
    N = length(model.xx);
    
    % Create new model
    F = scatteredInterpolant(model.zz',model.xx',model.v1D');
    F.Method = 'linear';
    W = F(Zg,Xg);
    [dimz , dimx] = size(W);
    for i = 1:dimx
        W(1:dimz<ElevFMM(i),i) = 0.01;
    end
    W(W < 0.01) = 0.01;
    dW = diff(W)/delta_Z;
    
    for ix = 1:Nx
        dW(1:Nz<ElevFMM(ix),ix) = 0;
    end
    
    cnt=cnt+1;
    
    % Update running mean and variance calculation
    Wmean0 = Wmean;
    Wmean = Wmean0 + (W-Wmean0)/(cnt-1);
    Wvar = Wvar+(W-Wmean).*(W-Wmean0);
    
    % Update running mean and variance calculation
    dWmean0 = dWmean_o;
    dWmean_o = dWmean0 + (dW-dWmean0)/(cnt-1);
    dWvar = dWvar+(dW-dWmean_o).*(dW-dWmean0);

end

% Create a polygon for area above ground surface
polygonX = [Topo(:,1)', max(Topo(:,1))+delta_X/2, max(Topo(:,1))+delta_X/2, min(Topo(:,1))-delta_X/2, min(Topo(:,1))-delta_X/2];
polygonY = max(Topo(:,2)) - Topo(:,2)';
polygonY = [polygonY, polygonY(length(polygonY)), -delta_Z/2, -delta_Z/2, polygonY(1)];

%% generate travel time curve
clear Tm

for ishot = 1:Nshot
    
    % Define source location
    start_point = [ZsrcFMM(ishot); XsrcFMM(ishot)];
    
    % Which data are from this shot?
    iind = find(SrcNumber==ishot);
    
    % Define receiver locations
    end_points = [ZrecFMM(iind)';XrecFMM(iind)'];
    
    % Find min and max X coordinates for this shot
    maxi = max([end_points(2,:) start_point(2,:)]);
    mini = min([end_points(2,:) start_point(2,:)]);
    
    % Define source and receiver locations on reduced domain
    sp2 = start_point;
    sp2(2,:) = sp2(2,:) - mini+1;
    
    ep2 = end_points;
    ep2(2,:) = ep2(2,:) - mini+1;
       
    options.nb_iter_max = Inf;
    
    % Run FMM on reduced domain
    D = perform_fast_marching(W(:,mini:maxi), sp2, options);
    
    % Assign result to traveltime vector
    for ii = 1:length(iind)
        Tm(iind(ii),1) = (maxZ-minZ)*D(ep2(1,ii),ep2(2,ii))';
    end
    
end

oldMaster = Master;
for i = 1:length(oldMaster)
    oldMaster(i,1) = oldMaster(i,1) + rand*1e-7;
end
oldMaster2 = oldMaster;
oldMaster2(oldMaster(:,2)==0,:) = [];

[~,newMaster_id] = sort(Master(:,3)); % sort by source location
newMaster = Master(newMaster_id,:);
oldMaster = oldMaster(newMaster_id,:);

mmodel = zeros(length(newMaster),1);
mdata = mmodel;
for i = 1:length(newMaster)
    if newMaster(i,2) ~= 0 % when the shot isn't collocated with geophone
        [~ , id] = min(abs(oldMaster2(:,1)-oldMaster(i,1)));
        mmodel(i) = Tm(id);
        mdata(i) = T(id);
    end
end

H=figure(2);clf;

hold on
k = 0;
for i = 1:length(newMaster)-1
    if newMaster(i,3) == newMaster(i+1,3)
        k = k+1;
        junk(k,1) = newMaster(i,1);
        junk(k,2) = newMaster(i,4);
        mmod(k,1) = mmodel(i);
    else
        k = k+1;
        junk(k,1) = newMaster(i,1);
        junk(k,2) = newMaster(i,4);
        mmod(k,1) = mmodel(i);
        plot(junk(:,2),junk(:,1)*1e3,'linewidth',2); %plot data
        plot(junk(:,2),mmod*1e3,'k','linewidth',.5); %plot model
        clear junk mmod
        k = 0;
    end
end
k = k+1;
junk(k,1) = newMaster(i+1,1);
junk(k,2) = newMaster(i+1,4);
mmod(k,1) = mmodel(i+1);

plot(junk(:,2),junk(:,1)*1e3,'linewidth',2);
plot(junk(:,2),mmod*1e3,'k','linewidth',.5); %plot model
xlim([min(Master(:,4)) max(Master(:,4))])
xlabel('Distance (m)');ylabel('Arrival time (ms)');
set(gca,'fontsize',13);

imfile = sprintf('%s/%s_TravelTimeFit.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 2.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [2.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/%s_TravelTimeFit.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% plot mean misfit of the velocity model
H=figure(3);clf;

tmp_M = Master;
tmp_M(tmp_M(:,2)==0,:) = [];
med_misfit = median(abs(T-Tm)*1e3);
mean_misfit = mean(abs(T-Tm)*1e3);

subplot(1,2,1);
% plot(abs(tmp_M(:,2)),abs(T-Tm)*1e3,'bo');
dscatter(abs(tmp_M(:,2)),abs(T-Tm)*1e3,'msize',50);
hold on;plot([0 max(abs(tmp_M(:,2)))],[mean_misfit mean_misfit],'k','linewidth',2);
xlabel('Source - Receiver Distance (m)');
ylabel('Mean misfit (ms)');
title(['Mean misfit: ' num2str(mean_misfit) ' ms']);
grid on;
set(gca,'fontsize',14);

subplot(1,2,2);
hist((T-Tm)*1e3,40);
xlabel('Misfit (ms)');
title(['STD: ' num2str(std((T-Tm)*1e3)) ' ms']);

imfile = sprintf('%s/Travel_Time_Misfit_%s.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 2*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [2*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Travel_Time_Misfit_%s.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% plot raypath
H=figure(4);clf;set(gca,'Fontsize',14);box on

X = Xg(1,:);
deep_ray = X';
deep_ray(:,2) = 0;
RayPath = [0 0];

xlabel('Distance (m)');ylabel('Depth (m)');

set(gca,'ydir','reverse');

dX = delta_X;

k = 0; %counter
for ishot = 1:Nshot
    
    % Define source location
    start_point = [ZsrcFMM(ishot); XsrcFMM(ishot)];
    
    % Which data are from this shot?
    iind = find(SrcNumber==ishot);
    
    % Define receiver locations
    end_points = [ZrecFMM(iind)';XrecFMM(iind)'];
    
    % Find min and max X coordinates for this shot
    maxi = max([end_points(2,:) start_point(2,:)]);
    mini = min([end_points(2,:) start_point(2,:)]);
    
    
    % Define source and receiver locations on reduced domain
    sp2 = start_point;
    sp2(2,:) = sp2(2,:) - mini+1;
    
    ep2 = end_points;
    ep2(2,:) = ep2(2,:) - mini+1;
    
    
    options.nb_iter_max = Inf;
    
    % Run FMM on reduced domain
    D = perform_fast_marching(Wmean, start_point, options);
    
    gpath = compute_geodesic(D,end_points);
    
    hold on;
    
    for i = 1:length(gpath)
        plot(gpath{i}(2,:)*dX+minX,gpath{i}(1,:)*dX,'k');
        hold on;
        k = k+1;
        [M,~] = size(RayPath);
        N = length(gpath{i});
        RayPath(M:M+N-1,1) = gpath{i}(2,:)*dX+minX;
        RayPath(M:M+N-1,2) = gpath{i}(1,:)*dX;
    end
%      plot(start_point(2),start_point(1),'ro');
end
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
axis image;

p1=6;
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
imfile = sprintf('%s/Raypath_%s.pdf',figfolder,pronum);
set(gcf,'PaperPositionMode','auto')
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Raypath_%s.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Estimate ray path density
[y, x] = size(Wmean);
dX = delta_X;
ray_threshold = 1; % minimum ray path number
ray_smooth = 5; % radius of a median fitler
RayDen0 = zeros(y,x);
mask = zeros(y,x);

MinX = min(RayPath(:,1))-dX;
MinY = min(RayPath(:,2))-dX;

for i = 1:length(RayPath)
    tmp_x = round((RayPath(i,1)-MinX)/dX);
    tmp_y = round((RayPath(i,2)-MinY)/dX);
    if tmp_x < x && tmp_y < y
        RayDen0(tmp_y,tmp_x) = RayDen0(tmp_y,tmp_x)+1;
    end
end

for i = 1:x
    for j = 1:y
        if RayDen0(j,i) ~= 0
            deep_ray(i,1) = (i-1)*dX+minX;
            deep_ray(i,2) = (j+1)*dX;
            mask(1:j,i) = 1;
        end
    end
end

mask(mask==0) = nan;

RayDen = medfilt2(RayDen0,[ray_smooth ray_smooth]);
RayDen(RayDen < ray_threshold) = nan;
RayDen(isnan(RayDen)==0) = 1;

H=figure(26);
imagesc(Xg(1,:)',Z(1,:),log10(RayDen0));axis image;colormap([1 1 1;crameri('vik')]);
title(sprintf('Log ray path density %s',pronum),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/RayPathDensity_%s.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/RayPathDensity_%s.fig',figfolder,pronum);
savefig(H,imfile,'compact');

% add one raw in the bottom of dWmean so the size matches
[y,x] = size(dWmean_o);
dWmean = dWmean_o;
dWmean(y+1,:) = dWmean_o(y,:);

mask_Wmean = Wmean .* RayDen;
mask_dWmean = dWmean .* RayDen;
mask_std = sqrt(Wvar/cnt) .* RayDen;

%%  Mean model
H=figure(5);clf;
imagesc(Xg(1,:)',Z,Wmean);daspect([1 1 1]);
colormap(cc);colorbar;
caxis([0 4000]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
plot(deep_ray(:,1),deep_ray(:,2),'w--','linewidth',2);
title(sprintf('Mean velocity (m/s) %s',pronum),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Profile_%s_MeanVel.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_MeanVel.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Standard deviation of model
H=figure(6);clf;
imagesc(Xg(1,:)',Z(1,:),sqrt(Wvar/cnt));daspect([1 1 1]);
colormap(cstd);colorbar;
caxis([0 1000]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
plot(deep_ray(:,1),deep_ray(:,2),'w--','linewidth',2);
title(sprintf('STD in velocity (m/s)'),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Profile_%s_StdVel.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_StdVel.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% coefficient of variance (std / mean)
CoV = sqrt(Wvar/cnt)./Wmean*100;
H=figure(16);clf;
imagesc(Xg(1,:)',Z(1,:),CoV);daspect([1 1 1]);
colormap(cstd);colorbar;
caxis([0 50]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
plot(deep_ray(:,1),deep_ray(:,2),'w--','linewidth',2);
title(sprintf('Coefficient of variance (percent)'),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Profile_%s_CoefVar.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_CoefVar.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Mean vertical gradient (i.e. strength of interface)
H=figure(7);clf;
imagesc(Xg(1,:)',Z(1,:),dWmean);daspect([1 1 1]);
colorbar;colormap(ccc);
% caxis([0 max(max(dWmean))*0.4]);
caxis([-100 200]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
plot(deep_ray(:,1),deep_ray(:,2),'w--','linewidth',2);
title(sprintf('Mean vertical gradient (m/s) %s',pronum),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Profile_%s_MeanGrad.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_MeanGrad.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Masked Mean model (crop out regions where CoV < a threshold)
CoV_threshold = 40; % percent

mask_CoV = CoV;
mask_CoV(mask_CoV < CoV_threshold) = 1;
mask_CoV(mask_CoV~=1) = nan;

[y, x] = size(Wmean);
mask_offset = ones(y,x);
for i = 1:x
    if i < min(XrecFMM) || i > max(XrecFMM)
        mask_offset(:,i) = nan;
    end
end

H=figure(8);clf;
imagesc(Xg(1,:)',Z,mask_Wmean .* mask_CoV .* mask_offset);daspect([1 1 1]);
colormap(cc);colorbar;
caxis([0 4000]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
title(sprintf('Masked Mean velocity (m/s) %s',pronum),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Masked_%s_MeanVel.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Masked_%s_MeanVel.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Interpolate masked mean model
[x,y] = size(mask_Wmean);
mask_Wmean2 = mask_Wmean .* mask_CoV .* mask_offset;
S = mask_Wmean2(:);
nanS = find(isnan(mask_Wmean2)==0);
S_s = S(nanS);
[yi,xi] = meshgrid(1:y,1:x);
Xc = xi(:);
Yc = yi(:);
Xs = Xc(nanS);
Ys = Yc(nanS);
mask_W_intp = griddata(Xs,Ys,S_s,xi,yi,'cubic');
mask_W_intp = mask_W_intp .* mask .* mask_offset;

H=figure(25);clf;
imagesc(Xg(1,:)',Z,mask_W_intp);daspect([1 1 1]);
colormap(cc);colorbar;
caxis([0 4000]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
title(sprintf('Interpolated Mean velocity (m/s) %s',pronum),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Masked_Interp_%s_MeanVel.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Masked_Interp_%s_MeanVel.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Masked Mean vertical gradient (i.e. strength of interface)

H=figure(10);clf;
imagesc(Xg(1,:)',Z(1,:),mask_dWmean);daspect([1 1 1]);
colorbar;colormap(ccc);
% caxis([0 max(max(dWmean))*0.4]);
caxis([-100 300]);
hold on;patch(polygonX,polygonY,'w');
plot(Topo(:,1),max(Topo(:,2)) - Topo(:,2),'k','linewidth',2);
title(sprintf('Mean vertical gradient (m/s) Profile %s',pronum),'Fontsize',14, 'Interpreter', 'none');
xlabel('Distance (m)');ylabel('Depth (m)')

imfile = sprintf('%s/Masked_%s_MeanGrad.pdf',figfolder,pronum);
p1=4.5;

set(gcf,'PaperPositionMode','auto')
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Masked_%s_MeanGrad.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Histograms for Number of layers and Noise hyperparameter (combine all chains)

H=figure(11);clf;set(gca,'Fontsize',14);box on
hist(Nuclei(burn:Nens-1),unique(Nuclei(burn:Nens-1)))
title(sprintf('Number of control points, N=%d, Profile %s',cnt,pronum),'Fontsize',14, 'Interpreter', 'none')
xlabel('Control points','Fontsize',14);ylabel('Frequency','Fontsize',14)

p1=4.5;
set(H,'Units','Inches','Position',[1 1 1.1*p1 p1])
imfile = sprintf('%s/Profile_%s_NumLayers.pdf',figfolder,pronum);
set(gcf,'PaperPositionMode','auto')
set(gcf,'Units','Inches', 'PaperSize', [1.1*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');
imfile = sprintf('%s/Profile_%s_NumLayers.fig',figfolder,pronum);
savefig(H,imfile,'compact');

H=figure(12);clf;set(gca,'Fontsize',14);box on
% convert from natural log to 10 based
xsig10 = log10(exp(xsig));
hist(xsig10(burn:Nens-1),50)
title(sprintf('Noise hyperparameter, N=%d, Profile %s',cnt,pronum),'Fontsize',14, 'Interpreter', 'none')
xlabel('Log seconds','Fontsize',14);ylabel('Frequency','Fontsize',14)

p1=4.5;
set(H,'Units','Inches','Position',[1 1 1.1*p1 p1])
imfile = sprintf('%s/Profile_%s_NoiseVar.pdf',figfolder,pronum);
set(gcf,'PaperPositionMode','auto')
set(gcf,'Units','Inches', 'PaperSize', [1.1*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');
imfile = sprintf('%s/Profile_%s_NoiseVar.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Raw misfit function evolution (combine all chains)
H=figure(13);clf;set(gca,'Fontsize',14);box on
semilogx((1:Nens)*datsav,sqrt(E0/Ndata)*1e3,'k.','linewidth',1.5) % plot in log scale
set(gca,'xlim',[1*datsav,Nens*datsav])
title(sprintf('Raw misfit, Profile %s',pronum),'Fontsize',14, 'Interpreter', 'none')
xlabel('Saved iteration','Fontsize',14);ylabel('RMSE misfit (ms)','Fontsize',14)

p1=3.5;
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
imfile = sprintf('%s/Profile_%s_RawMisfit.pdf',figfolder,pronum);
set(gcf,'PaperPositionMode','auto')
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_RawMisfit.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Noise hyperparameter evolution (combine all chains)
H=figure(14);clf;set(gca,'Fontsize',14);box on
semilogx((1:Nens)*datsav,exp(xsig)*1e3,'k','linewidth',1.5)
set(gca,'xlim',[1*datsav,Nens*datsav])
title(sprintf('Noise hyperparameter, Profile %s',pronum),'Fontsize',14, 'Interpreter', 'none')
xlabel('Iteration','Fontsize',14);ylabel('Noise hyp. (ms)','Fontsize',14)

p1=3.5;
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
imfile = sprintf('%s/Profile_%s_NoiseEvol.pdf',figfolder,pronum);
set(gcf,'PaperPositionMode','auto')
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_NoiseEvol.fig',figfolder,pronum);
savefig(H,imfile,'compact');

%% Misfit function evolution (combine all chains in log scale)
H=figure(15);clf;set(gca,'Fontsize',14);box on
semilogx((1:Nens)*datsav,E/Ndata,'k','linewidth',1.5)
set(gca,'xlim',[1*datsav,Nens*datsav])
title(sprintf('Misfit, Profile %s',pronum),'Fontsize',14, 'Interpreter', 'none')
xlabel('Saved iteration','Fontsize',14);ylabel('Chi^2','Fontsize',14)

p1=3.5;
set(H,'Units','Inches','Position',[1 1 1.5*p1 p1])
imfile = sprintf('%s/Profile_%s_Misfit.pdf',figfolder,pronum);
set(gcf,'PaperPositionMode','auto')
set(gcf,'Units','Inches', 'PaperSize', [1.5*p1 p1]);
print(H,imfile,'-dpdf','-cmyk');

imfile = sprintf('%s/Profile_%s_Misfit.fig',figfolder,pronum);
savefig(H,imfile,'compact');
