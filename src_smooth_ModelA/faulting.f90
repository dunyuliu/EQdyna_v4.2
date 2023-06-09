SUBROUTINE faulting(ift,nftnd,numnp,neq,lstr,fnms,brhs,d,v,x,maxm,id1,locid,dof1,&
		n4onf,fltsta,nsmp,fnft,fltslp,un,us,ud,fric,arn,r4nuc,arn4m,slp4fri,anonfs,itmp,me,nt,miuonf,state)
use globalvar
implicit none
!===================================================================!
!Day et al.(2005)'s formulation for staggered v/stress structure & central difference/ B.Duan 2006/11/23
!Extended to 3D case. B.Duan 2007/01/26
!===================================================================!
logical::lstr
character(len=30)::foutmov,mm
!===================================================================!
integer(kind=4)::ift,nftnd,numnp,neq,i,i1,j,k,n,isn,imn,n4onf,itmp,me,maxm,ifout,nt,ipatchx,ipatchz
integer(kind=4)::anonfs(3,itmp),nsmp(2,nftnd),id1(maxm),locid(numnp),dof1(numnp)
!===================================================================!
real (kind=8) ::slipn,slips,slipd,slip,slipraten,sliprates,sliprated,&
sliprate,xmu,mmast,mslav,mtotl,fnfault,fsfault,fdfault,tnrm,tstk, &
tdip,taox,taoy,taoz,ttao,taoc,ftix,ftiy,ftiz,trupt,tr,&
tmp1,tmp2,tmp3,tmp4,tnrm0,rcc,fa,fb
real(kind=8),dimension(nftnd)::fnft,arn,r4nuc,arn4m,slp4fri,miuonf
real(kind=8),dimension(3,nftnd)::un,us,ud,fltslr
real(kind=8),dimension(10,nftnd)::fltslp
real(kind=8)::fric(20,nftnd),fltsta(10,nplpts-1,n4onf),fvd(6,2,3),brhs(neq),&
	d(ndof,numnp),v(ndof,numnp),x(ndof,numnp),fnms(numnp) 
!--------------------------------------------------------------------
!RSF from Bin. 2016.08.28
  real (kind=8),dimension(nftnd) :: state, A, Vw  !RSF
  real (kind=8) :: rr,R0,T,F,G,dtao0,dtao=0.0 !RSF
  real (kind=8) :: statetmp, v_trial, T_coeff!RSF
  integer (kind=4) :: iv,ivmax  !RSF
  real (kind=8) :: tstk0, tdip0, tstk1, tdip1, ttao1, taoc_old, taoc_new !RSF
  real (kind=8) :: dxmudv, rsfeq, drsfeqdv, vtmp !RSF
  real (kind=8) :: accn,accs,accd, accx, accy, accz, Rx, Ry, Rz, mr
  logical :: qs	
real (kind=8),dimension(3,nftnd) ::stresses!2016.08.28 stores norm,shear&yield strength for movies
real(kind=8)::boundxleft,boundxright,boundztop,boundzbottom  
!===================================================================!
fvd=0.0
do i=1,nftnd	!just fault nodes
!-------------------------------------------------------------------!
    !RSF nucleate by imposing a horizontal shear traction perturbation
	!2016.08.28
    if((C_nuclea==1).and.(friclaw == 3 .or. friclaw == 4).and.(ift == nucfault)) then
       R0 = 3000.0d0
       dtao0 = 45.0d6
       T = 1.0d0
       F = 0.0d0
       rr=sqrt((x(1,nsmp(1,i))-xsource)**2+(x(3,nsmp(1,i))-zsource)**2)    
       if (rr<R0)    F=dexp(rr**2/(rr**2-R0**2))
       G = 1.0d0
       if (time<=T)  G=dexp((time-T)**2/(time*(time-2*T)))
       dtao=dtao0*F*G
    endif
!-------------------------------------------------------------------!	
    fnfault = fric(7,i) !initial forces on the fault node
    fsfault = fric(8,i)+dtao !norm, strike, dip components directly
    fdfault = 0.0
	isn = nsmp(1,i)
	imn = nsmp(2,i)
	do j=1,2  !1-slave, 2-master
		do k=1,3  !1-x comp, 2-y comp, 3-z comp
		!          fvd(k,j,1) = brhs(id(k,nsmp(j,i)))  !1-force
			fvd(k,j,1) = brhs(id1(locid(nsmp(j,i))+k))  !1-force !DL 
			fvd(k,j,2) = v(k,nsmp(j,i)) !2-vel
			fvd(k,j,3) = d(k,nsmp(j,i)) !3-di,iftsp
			!fvd(k,j,3) = d(k,nsmp(j,i,ift)) + rdampk(1)*fvd(k,j,2) !3-di,iftsp
		enddo
	enddo
	!...resolve x,y,z components onto normal, strike and dip components.
	!   B.D. 1/26/07
	do j=1,3    !1-force,2-vel,3-disp
		do k=1,2  !1-slave,2-master
			fvd(4,k,j) = fvd(1,k,j)*un(1,i) + fvd(2,k,j)*un(2,i) + fvd(3,k,j)*un(3,i)  !4-norm
			fvd(5,k,j) = fvd(1,k,j)*us(1,i) + fvd(2,k,j)*us(2,i) + fvd(3,k,j)*us(3,i)  !5-strike
			fvd(6,k,j) = fvd(1,k,j)*ud(1,i) + fvd(2,k,j)*ud(2,i) + fvd(3,k,j)*ud(3,i)  !6-dip
		enddo
	enddo
	slipn = fvd(4,2,3) - fvd(4,1,3)
	slips = fvd(5,2,3) - fvd(5,1,3)
	slipd = fvd(6,2,3) - fvd(6,1,3)
	slip = sqrt(slipn**2 + slips**2 + slipd**2) !slip mag
	fltslp(1,i) = slips  !save for final slip output
	fltslp(2,i) = slipd
        fltslp(3,i) = slipn
	!fltslp(3,i) = slipn  !normal should be zero, but still keep to ensure
	slipraten = fvd(4,2,2) - fvd(4,1,2)
	sliprates = fvd(5,2,2) - fvd(5,1,2)
	sliprated = fvd(6,2,2) - fvd(6,1,2)
	fltslr(1,i) = sliprates  !save for final slip output
	fltslr(2,i) = sliprated
        fltslr(3,i) = slipraten
        fltslp(4,i) = fltslr(1,i)
        fltslp(5,i) = fltslr(2,i)
        fltslp(6,i) = fltslr(3,i)
	sliprate = sqrt(slipraten**2+sliprates**2+sliprated**2)
	if (sliprate>fltslp(7,i)) then 
		fltslp(7,i)=sliprate
	endif
	!...path-itegrated slip for slip-weakening. B.D. 8/12/10
	slp4fri(i) = slp4fri(i) + sliprate * dt
	!...calculate moment rate and moment if needed. B.D. 8/11/10
	!  also, max slip rate for early termination.
	!...for homogeneous material, i.e., only myshr(1). B.D. 1/3/12
	! or for heterogeneous case, but mushr(1) for rupture fault.
	!
	!...nodal mass. Mass of each element may not be distributed among its 
	! nodes evenly. Instead, distribution is related to element shape. 
	!   Note: nodal mass should not be directly obtained from left-hand-side
	! diagnoal mass matrix, because that's the effective mass, which takes 
	! damping coefficient into accout. Instead, I computed nodal mass from 
	! element mass and assembled in "qdct2.f90".B.D.7/3/05
	mslav = fnms(isn)		
	mmast = fnms(imn)
	mtotl = mslav + mmast
	!
	!...trial traction to enforce continuity. B.D. 11/23/06
	!...divided by the associated area to get traction from force for EQdyna3d v2.1.2.
	!   initial stress, not initial force (f*fault) used here. B.D. 2/28/08
	!...no fault initial stress in elastoplastic rheology. B.D. 1/8/12
	mtotl = mtotl * arn(i)
	!*.*Sep.13.2015/D.L.	
	if (C_elastic==0) then!Plastic 	
		tnrm = (mslav*mmast*((fvd(4,2,2)-fvd(4,1,2))+(fvd(4,2,3)-fvd(4,1,3))/dt)/dt &
			+ mslav*fvd(4,2,1) - mmast*fvd(4,1,1)) / mtotl          
		tstk = (mslav*mmast*(fvd(5,2,2)-fvd(5,1,2))/dt + mslav*fvd(5,2,1) &
			- mmast*fvd(5,1,1)) / mtotl
		tdip = (mslav*mmast*(fvd(6,2,2)-fvd(6,1,2))/dt + mslav*fvd(6,2,1) &
			- mmast*fvd(6,1,1)) / mtotl
	else!Elastic
		tnrm = (mslav*mmast*((fvd(4,2,2)-fvd(4,1,2))+(fvd(4,2,3)-fvd(4,1,3))/dt)/dt &
			+ mslav*fvd(4,2,1) - mmast*fvd(4,1,1)) / mtotl + fnfault         
		tstk = (mslav*mmast*(fvd(5,2,2)-fvd(5,1,2))/dt + mslav*fvd(5,2,1) &
			- mmast*fvd(5,1,1)) / mtotl + fsfault
		tdip = (mslav*mmast*(fvd(6,2,2)-fvd(6,1,2))/dt + mslav*fvd(6,2,1) &
			- mmast*fvd(6,1,1)) / mtotl + fdfault
	endif		
	ttao = sqrt(tstk*tstk + tdip*tdip) !total shear magnitude	  
	!
	!...friction law to determine friction coefficient
	!   slip-weakening only so far. B.D. 1/26/07
	!... based on choices, call corresponding friction laws.
	! B.D. 10/8/08
if (friclaw==1.or.friclaw==2)then!Differ 1&2 and 3&4	
	if(friclaw == 1) then
		call slip_weak(slp4fri(i),fric(1,i),xmu)
	elseif(friclaw == 2) then
		trupt =  time - fnft(i)
		call time_weak(trupt,fric(1,i),xmu)
	endif
	! !......for nucleation zone of the nucleation fault,which initiates rupture,
	! !	rupture propagates at a fixed speed to drop "xmu". B.D. 8/31/06
	!if(ift == nucfault .and. xmu > fric(2,i)) then	
		! !only nucleation fault and before finishing dropping, do...
		! if(r4nuc(i) <= srcrad0) then !only within nucleation zone, do...
			! tr = r4nuc(i) / vrupt0
			! if(tr <= time) then !only ready or already fail, do...
				! trupt = time - tr
			! call time_weak(trupt,fric(1,i),xmu)
			! endif
		! endif
		!only nucleation fault and before finishing dropping, do...
	if (C_Nuclea==1) then	
		if(r4nuc(i)<=srcrad0) then !only within nucleation zone, do...
			tr=(r4nuc(i)+0.081*srcrad0*(1./(1-(r4nuc(i)/srcrad0)*(r4nuc(i)/srcrad0))-1))/(0.7*3464.)
		else
			tr=1.0e9 
		endif
		if(time<tr) then 
			fb=0.0
		elseif ((time<(tr+critt0)).and.(time>=tr)) then 
			fb=(time-tr)/critt0
		else 
			fb=1.0
		endif
		tmp1=fric(1,i)+(fric(2,i)-fric(1,i))*fb
		tmp2=xmu
		xmu=min(tmp1,tmp2)  !minimum friction used. B.D. 2/16/13	
	endif
	!endif
	!
	!...adjust tstk,tdip and tnrm based on jump conditions on fault.
	!   before calculate taoc, first adjust tnrm if needed. 
	!   after this, they are true (corrected) values. B.D. 11/23/06
	!   cohesion is added here. B.D. 2/28/08
	!...for SCEC TPV10/11, no opening is allowed. B.D. 11/24/08
	!if(tnrm > 0) tnrm = 0   !norm must be <= 0, otherwise no adjust
	!taoc = cohes - xmu * tnrm
	!...for ExGM 100 runs, no opening allowed means following.
	!  B.D. 8/12/10
	if((tnrm+fric(6,i))>0) then
		tnrm0 = 0.0
	else
		tnrm0 = tnrm+fric(6,i)
	endif
	taoc = fric(4,i) - xmu *tnrm0
	!taoc = cohes - xmu * tnrm0
	!if(tnrm > 0) tnrm = 0   !norm must be <= 0, otherwise no adjust
	!taoc = fistr(5,i) - xmu * tnrm
	if(ttao > taoc) then
		tstk = tstk * taoc / ttao
		tdip = tdip * taoc / ttao
		if(fnft(i)>600) then	!fnft should be initialized by >10000
			if(sliprate >= 0.001) then	!first time to reach 1mm/s
				fnft(i) = time	!rupture time for the node
			endif
		endif
	endif
        fltslp(8,i) = tstk
        fltslp(9,i) = tdip
        fltslp(10,i) = tnrm0
	!
	!...add the above fault boundary force and initial force to elastic
	!	force of the split nodes. 
	!   first resolve normal, strike and dip back to x-,y-,z-. 
	!   then subtract them from slave, add to master as the above calculation
	!   based on this convention. see Day et al. (2005). B.D. 11/23/06
	!...due to traction, not force used in friction law above, need area to 
	!   convert traction to force for v2.1.2. B.D. 2/28/08
	taox = (tnrm*un(1,i) + tstk*us(1,i) + tdip*ud(1,i))*arn(i)
	taoy = (tnrm*un(2,i) + tstk*us(2,i) + tdip*ud(2,i))*arn(i)
	taoz = (tnrm*un(3,i) + tstk*us(3,i) + tdip*ud(3,i))*arn(i)
	!*.*Sep.13.2015/D.L.	
	if (C_elastic==0) then!Plastic	
		brhs(id1(locid(isn)+1)) = brhs(id1(locid(isn)+1)) + taox !brhs(id1(loci(1,imn)+1))
		brhs(id1(locid(isn)+2)) = brhs(id1(locid(isn)+2)) + taoy
		brhs(id1(locid(isn)+3)) = brhs(id1(locid(isn)+3)) + taoz
		brhs(id1(locid(imn)+1)) = brhs(id1(locid(imn)+1)) - taox
		brhs(id1(locid(imn)+2)) = brhs(id1(locid(imn)+2)) - taoy
		brhs(id1(locid(imn)+3)) = brhs(id1(locid(imn)+3)) - taoz
	else!Elastic
		ftix = (fnfault*un(1,i) + fsfault*us(1,i) + fdfault*ud(1,i))*arn(i)
		ftiy = (fnfault*un(2,i) + fsfault*us(2,i) + fdfault*ud(2,i))*arn(i)
		ftiz = (fnfault*un(3,i) + fsfault*us(3,i) + fdfault*ud(3,i))*arn(i)  
		 brhs(id1(locid(isn)+1)) = brhs(id1(locid(isn)+1)) + taox - ftix
		 brhs(id1(locid(isn)+2)) = brhs(id1(locid(isn)+2)) + taoy - ftiy
		 brhs(id1(locid(isn)+3)) = brhs(id1(locid(isn)+3)) + taoz - ftiz
		 brhs(id1(locid(imn)+1)) = brhs(id1(locid(imn)+1)) - taox + ftix
		 brhs(id1(locid(imn)+2)) = brhs(id1(locid(imn)+2)) - taoy + ftiy
		 brhs(id1(locid(imn)+3)) = brhs(id1(locid(imn)+3)) - taoz + ftiz
!For Cushing v1 Oct25.2019	
!For Cushing v2 Oct28.2019
!                tmp4 = ipatch/13	
!		ipatchx = floor(tmp4) + 1
!		ipatchz = mod(ipatch,13)
 !               if (ipatchz == 0) then
  !                      ipatchx = ipatchx - 1
   !                     ipatchz = ipatchz + 13
    !            endif
!		boundxleft = (ipatchx - 1)*500.0d0  -2.25d3
!		boundxright = ipatchx * 500.0d0 -2.25d3
!		boundztop = -150.0d0 - (ipatchz - 1)*500.0d0
!		boundzbottom = -150.0d0 - ipatchz*500.0d0
	!	if (x(1,isn)>boundxleft.and.x(1,isn)<boundxright.and.x(3,isn)>boundzbottom.and.x(3,isn)<boundztop.and.dt*nt<0.08d0) then
	!		if (idirection == 1) then
         !       brhs(id1(locid(isn)+1)) = brhs(id1(locid(isn)+1)) - 1.0d6*arn(i)
	!			brhs(id1(locid(imn)+1)) = brhs(id1(locid(imn)+1)) + 1.0d6*arn(i)
	!		elseif (idirection == 2) then
	!			brhs(id1(locid(isn)+2)) = brhs(id1(locid(isn)+2)) - 1.0d6*arn(i)
	!			brhs(id1(locid(imn)+2)) = brhs(id1(locid(imn)+2)) + 1.0d6*arn(i)
	!		elseif (idirection == 3) then 
	!			brhs(id1(locid(isn)+3)) = brhs(id1(locid(isn)+3)) - 1.0d6*arn(i)				
	!			brhs(id1(locid(imn)+3)) = brhs(id1(locid(imn)+3)) + 1.0d6*arn(i)
	!		endif
	!	endif
        endif	
elseif (friclaw==3.or.friclaw==4)then
!RSF: friclaw=3 selects ageing law, friclaw=4 selects slip law and strong rate weakening  B.L. 1/8/16
      slipn = slipn + fric(16,i) * time 
      slips = slips + fric(17,i) * time
      slipd = slipd + fric(18,i) * time
      slip = sqrt(slips**2 + slipd**2) !slip mag

      slipraten =  slipraten + fric(16,i) 
      sliprates =  sliprates + fric(17,i)
      sliprated =  sliprated + fric(18,i)
      sliprate = sqrt(sliprates**2+sliprated**2)
		if(fnft(i)>600) then	!fnft should be initialized by >10000
			if(sliprate >= 0.001) then	!first time to reach 1mm/s
				fnft(i) = time	!rupture time for the node
			endif
		endif
      v_trial = sliprate
      mr =   mmast * mslav / (mmast+mslav) !reduced mass   
      T_coeff = arn(i)* dt / mr
      statetmp = state(i)  !RSF: a temporary variable to store the currently value of state variable. B.L. 1/8/16

      if(friclaw == 3) then
        call rate_state_ageing_law(v_trial,state(i),fric(1,i),xmu,dxmudv) !RSF
      else
        call rate_state_slip_law(v_trial,state(i),fric(1,i),xmu,dxmudv) !RSF
      endif 

      taoc_old = fric(4,i) - xmu * MIN(tnrm, 0.0d0)
	  tstk0=tstk
	  tdip0=tdip
      tstk1 = tstk0 - taoc_old*0.5d0 * (sliprates / sliprate) + fric(17,i)/T_coeff
      tdip1 = tdip0 - taoc_old*0.5d0 * (sliprated / sliprate) + fric(18,i)/T_coeff
      
      ttao1 = sqrt(tstk1*tstk1 + tdip1*tdip1)
  
        ivmax = 30  !RSF: maximum 30 loops for iteration, once a criterion is met, jump out of this loop. B.L. 1/8/16
  
      do iv = 1,ivmax
          state(i) = statetmp
          if(friclaw == 3) then
            call rate_state_ageing_law(v_trial,state(i),fric(1,i),xmu,dxmudv) !RSF
          else
            call rate_state_slip_law(v_trial,state(i),fric(1,i),xmu,dxmudv) !RSF
          endif 
  
          taoc_new = fric(4,i) - xmu * MIN(tnrm, 0.0d0)
  
          rsfeq = v_trial + T_coeff * (taoc_new*0.5d0 - ttao1)
          drsfeqdv = 1.0d0 + T_coeff * (-dxmudv * MIN(tnrm,0.0d0))*0.5d0  
 
        if(abs(rsfeq/drsfeqdv) < 1.d-14 * abs(v_trial) .and. abs(rsfeq) < 1.d-6 * abs(v_trial)) exit 
        vtmp = v_trial - rsfeq / drsfeqdv
        if(vtmp <= 0.0d0) then
          v_trial = v_trial/2.0d0
        else
          v_trial = vtmp
        endif
       
      enddo !iv

      if(v_trial < fric(19,i)) then
         v_trial = fric(19,i)
         taoc_new = ttao1 * 2.0
      endif

      tstk = taoc_old*0.5d0 * (sliprates / sliprate) + taoc_new*0.5d0 * (tstk1 / ttao1) 
      tdip = taoc_old*0.5d0 * (sliprated / sliprate) + taoc_new*0.5d0 * (tdip1 / ttao1) 
	stresses(1,i)=tnrm 
	stresses(2,i)=tstk
	stresses(3,i)=taoc_new
      accn = -slipraten/dt - slipn/dt/dt
      accs = (v_trial * (tstk1 / ttao1) - sliprates)/dt
      accd = (v_trial * (tdip1 / ttao1) - sliprated)/dt
  
      accx = accn*un(1,i) + accs*us(1,i) + accd*ud(1,i)
      accy = accn*un(2,i) + accs*us(2,i) + accd*ud(2,i)
      accz = accn*un(3,i) + accs*us(3,i) + accd*ud(3,i)
		if (C_elastic==0) then
		stop 777
		elseif (C_elastic==1) then
		Rx = brhs(id1(locid(isn)+1)) + brhs(id1(locid(imn)+1))
		Ry = brhs(id1(locid(isn)+2)) + brhs(id1(locid(imn)+2))
		Rz = brhs(id1(locid(isn)+3)) + brhs(id1(locid(imn)+3))
      brhs(id1(locid(isn)+1)) = (-accx + Rx/mmast) * mr
      brhs(id1(locid(isn)+2)) = (-accy + Ry/mmast) * mr
      brhs(id1(locid(isn)+3)) = (-accz + Rz/mmast) * mr
      brhs(id1(locid(imn)+1)) = (accx + Rx/mslav) * mr
      brhs(id1(locid(imn)+2)) = (accy + Ry/mslav) * mr
      brhs(id1(locid(imn)+3)) = (accz + Rz/mslav) * mr
		endif
endif
	!...Store fault forces and slip/slipvel for fault nodes 
	!		at set time interval.
	! note: forces will be transferred to stress later
	! B.D. 8/21/05
	!...now, they are directly traction (stress) in version 2.1.2.
	!   and can be written out here. B.D. 2/28/08
	!...Store only, no write out. B.D. 10/25/09
	if(n4onf>0.and.lstr) then	
		do j=1,n4onf
			if(anonfs(1,j)==i.and.anonfs(3,j)==ift) then !only selected stations. B.D. 10/25/09    
				fltsta(1,locplt-1,j) = time
				fltsta(2,locplt-1,j) = sliprates
				fltsta(3,locplt-1,j) = sliprated
				fltsta(4,locplt-1,j) = state(i)
				fltsta(5,locplt-1,j) = slips
				fltsta(6,locplt-1,j) = slipd
				fltsta(7,locplt-1,j) = slipn
				fltsta(8,locplt-1,j) = tstk
				fltsta(9,locplt-1,j) = tdip
				fltsta(10,locplt-1,j) = tnrm+fric(6,i)
			endif
		enddo 
	endif   
!	if (x(1,isn)==xsource.and.x(2,isn)==ysource.and.x(3,isn)==zsource)then
!		if (nt==1) then 
!		!rcc=miu*(S+1)
!		rcc=miuonf(i)*((fric(1,i)*abs(fnfault)-abs(fsfault))/(abs(fsfault)-fric(2,i)*abs(fnfault))+1)
!		!rc=rc*D0/delta_tao
!		rcc=rcc*fric(3,i)/(abs(fsfault)-fric(2,i)*abs(fnfault))
!		rcc=rcc*7*3.14/24
!			open(unit=9001,file='Rc.txt',form='formatted',status='unknown')
!				write(9001,*) 'Rc=',rcc,'miu=',miuonf(i)
!				write(9001,*) 'Fn=',fnfault,'Fs=',fsfault
!				write(9001,*) 'mius=',fric(1,i),'miud=',fric(2,i)
!				write(9001,*) 'Dc=',fric(3,i)
!			close(9001)			
!		endif
!		write(*,*)'S1:slip,ft',slips,fnft(i),r4nuc(i),tr
!		write(*,*)'source,taoc,ttao',(taoc_old+taoc_new)/2,ttao
		!write(*,*)'source,tnrm,tstk,tdip',tnrm,tstk,tdip
		!write(*,*)'source,brhs isn',brhs(id1(locid(isn)+1)),brhs(id1(locid(isn)+2)),brhs(id1(locid(isn)+3))	
!	endif
	! if (x(1,isn)==-5.7e3.and.x(2,isn)==0.0.and.x(3,isn)==-9.8e3)then
		! write(*,*)'S2:slips,fnft',slips,fnft(i)
		! write(*,*)'**OF,taoc,ttao',taoc,ttao
		! write(*,*)'**OF,tnrm,tstk,tdip',tnrm,tstk,tdip
		! ! write(*,*)'**OF,brhs isn',brhs(id1(locid(isn)+1)),brhs(id1(locid(isn)+2)),brhs(id1(locid(isn)+3))	
	! endif	
enddo	!ending i
!!$omp end parallel do	
!-------------------------------------------------------------------!
!-------------Late Sep.2015/ D.Liu----------------------------------!
!-----------Writing out results on fault for evert nstep------------!
if(mod(nt,20)==1.and.nt<5000) then 
	write(mm,'(i6)') me
	mm = trim(adjustl(mm))
	foutmov='fslipout_'//mm
	open(9002+me,file=foutmov,form='formatted',status='unknown',position='append')
		write(9002+me,'(7e18.7e4)') ((fltslp(j,ifout),j=1,3),fltslp(7,ifout),(fltslp(k,ifout),k=8,10),ifout=1,nftnd)
endif
!----nftnd for each me for plotting---------------------------------!
!if (nt==1) then
!	write(mm,'(i6)') me	
!	mm = trim(adjustl(mm))			
!	foutmov='fnode.txt'//mm
!	open(unit=9800,file=foutmov,form='formatted',status='unknown')
!		write(9800,'(2I7)') me,nftnd 
!	close(9800)			
!endif 	
!-------------------------------------------------------------------!	
end SUBROUTINE faulting	 
