!===================================================================!
MODULE globalvar
implicit none
save  
integer(kind=4)::iingl=11,ioutgl=12, ioutft=13,ioutrt1=14,&
  	ioutrt2=15,ioutst=16,ioutsl=17,ioutgm=18,ioutoff=19,&
    ioutrat=20,ioutdp=21
real(kind=8),dimension(9)::timeused=0.0
real(kind=8)::time1,time2,time=0.0, btime=0.0
external gethrtime	!this function in the SUN Fortran library   	   
integer(kind=4)::iexec=1,irank=0,numseq=1,nsd=3,ndof=3,numeg=1
integer(kind=4)::nen=8,ned=3,nee=24,nesd=3,nrowsh=4,nrowb=6,nrowc=6,nstr=6,noid=2
real(kind=8)::w	!integration weight	   	   
real(kind=8)::critd0,cohes,brangle
integer(kind=4)::nplpts,nstep,nhplt=1,nhplt1=2,nhshw=300   	    
integer(kind=4)::locplt=1,myrec=0
real(kind=8)::pi=3.1415926535897931d0,rdampm=0.0d0,rdampk=0.1d0
!-------------------------------------------------------------------!
!-------------Controllable parameters for EQdyna3d V4.0-------------! 
integer(kind=4)::C_elastic=1
!	1=elastic version;
!	0=plastic version;
integer(kind=4)::C_Nuclea=1
!	1=allow artificial nucleation;
!	0=disabled;
integer(kind=4)::nucfault=1,friclaw=2,ntotft=1
integer(kind=4)::C_Q=0!
!AAA:Only works with C_elastic==1.
!	1=allow Q attenuation;
!	0=do not allow Q.
integer(kind=4)::C_hg=1
!	1=KF78 hourglass control(HG);
!	2=Viscous HG
integer(kind=4)::C_dc=0!In driver.f90
!AAA: fault should be fixed.(mus==10000.)
!	1=allow double couple(DC) point source;
!	0=do not allow.
integer(kind=4)::nPML=6
!	Thickness (counted by nodes) of PML.
real(kind=8)::R=0.01d0! Theoretical reflection coefficient for PML
!	Other options for pairs of (nPML/R)
!	nPML/R=6/0.01;10/0.001;20/0.0001.Collino& Tsogka(2001)
real(kind=8)::kapa_hg=0.1d0!Coefficient for viscous HG.
!AAA:Only works when C_hg==2.
!	Typical valus varies from 0.05~0.15.Goudreau& Hallquist(1982).
real(kind=8)::rat=1.025d0
!	Enlarge ratio for buffers to use 
real(kind=8)::dx=100.d0,dy,dz!Element size.
integer(kind=4)::dis4uniF=100,dis4uniB=100
!Number of uniform sized elements normal to the fault
real(kind=8)::rhow=1000.,b11=0.926793,b33=1.073206,b13=-0.169029,&
	critt0=0.2d0,srcrad0=25000.0d0,vrupt0=3000.0d0,&!Info on forced rupture.
	bulk=0.1934,coheplas=1.36e6,tv=0.03,ccosphi,sinphi,mus,mud
real(kind=8)::xsource=0.0d3,ysource=0.0d0,zsource=-3.4d3!Nucleation point.
!===================================================================!
!Specify informations on on- and off- fault stations and
! model and fault geometries. 
integer(kind=4)::ninterval=1,nftmx,nonmx,nonfs(1)=9,n4nds=145,an4nds(2,145)
real(kind=8)::xonfs(2,9,1),x4nds(3,145)
real(kind=8)::surxmax=0e3,surxmin=0e3,surymax=0e3,surymin=0e3
real(kind=8)::xmin=-60.0d3,xmax=60.0d3,ymin=-58.0d3,ymax=62.0d3,zmin=-74.0d3,zmax=0.0d0
real(kind=8)::fxmin=-6.0d3,fxmax=6.0d3,fymin=0.0d0,fymax=0.0d0,fzmin=-8.0d3,fzmax=0.0d0
real(kind=8)::fstrike=270.0d0,fdip=90.0d0
real(kind=8)::fltxyz(2,4,1)
character(len=15)::projectname='Cushing_Forward_Smooth4v4',author='D.Liu'
!===================================================================!
!Specify maximum Vp for PML and timing information
real(kind=8)::vmaxPML=6320.0d0,term=20.0d0,dt=0.01d0

real(kind=8),allocatable,dimension(:,:)::dout
integer(kind=4),allocatable,dimension(:,:)::idhist
!===================================================================!
!3DMPI Partitioning along x/y/z axis, repect.
integer(kind=4)::npx=5,npy=5,npz=4,master=0,nprocs
integer(kind=4)::ipatch,idirection
logical,dimension(6)::fltMPI
integer(kind=4),dimension(6)::fltnum=0
integer(kind=4),allocatable,dimension(:)::fltgm
integer(kind=4),allocatable,dimension(:)::fltl,fltr,fltf,fltb,fltd,fltu
integer (kind=4),dimension(9)::numcount
!-------------------------------------------------------------------!    
end MODULE globalvar 	      
