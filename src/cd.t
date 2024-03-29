!#############################################################################
! module cd
! Centered difference scheme
!=============================================================================
subroutine centdiff(qdt,ixI^L,ixO^L,idim^LIM,qtC,wCT,qt,w,fC,dx^D,x)

! Advance the iws flow variables from t to t+qdt within ixO^L by centered 
! differencing in space the dw/dt+dF_i(w)/dx_i=S type equation. 
! wCT contains the time centered variables at time qtC for flux and source.
! w is the old value at qt on input and the new value at qt+qdt on output.

include 'amrvacdef.f'

integer, intent(in) :: ixI^L, ixO^L, idim^LIM
double precision, intent(in) :: qdt, qtC, qt, dx^D
double precision :: wCT(ixI^S,1:nw), w(ixI^S,1:nw)
double precision, intent(in) :: x(ixI^S,1:ndim)
double precision :: fC(ixI^S,1:nwflux,1:ndim)

double precision :: v(ixG^T,ndim), f(ixG^T)
double precision :: dxinv(1:ndim)
integer :: idims, iw, ix^L, hxO^L, ixC^L, jxC^L
logical :: transport
!-----------------------------------------------------------------------------

! An extra layer is needed in each direction for which fluxes are added.
ix^L=ixO^L;
do idims= idim^LIM
   ix^L=ix^L^LADDkr(idims,^D);
end do
if (ixI^L^LTix^L|.or.|.or.) then
   call mpistop("Error in CentDiff: Non-conforming input limits")
end if

^D&dxinv(^D)=-qdt/dx^D;

! Add fluxes to w
do idims= idim^LIM
   ix^L=ixO^L^LADDkr(idims,^D); ixCmin^D=ixmin^D; ixCmax^D=ixOmax^D;
   jxC^L=ixC^L+kr(idims,^D); 
   hxO^L=ixO^L-kr(idims,^D);

   call getv(wCT,x,ixI^L,ix^L,idims,f)
   v(ix^S,idims)=f(ix^S)

   do iw=1,nwflux
      ! Get non-transported flux
      call getflux(wCT,x,ixI^L,ix^L,iw,idims,f,transport)
      ! Add transport flux
      if (transport) f(ix^S)=f(ix^S)+v(ix^S,idims)*wCT(ix^S,iw)
      ! Center flux to interface
      fC(ixC^S,iw,idims)=half*(f(ixC^S)+f(jxC^S))
      if (slab) then
         fC(ixC^S,iw,idims)=dxinv(idims)*fC(ixC^S,iw,idims)
         w(ixO^S,iw)=w(ixO^S,iw)+(fC(ixO^S,iw,idims)-fC(hxO^S,iw,idims))
      else
         select case (idims)
         {case (^D)
            fC(ixC^S,iw,^D)=-qdt*mygeo%surfaceC^D(ixC^S)*fC(ixC^S,iw,^D)
            w(ixO^S,iw)=w(ixO^S,iw)+ &
                 (fC(ixO^S,iw,^D)-fC(hxO^S,iw,^D))/mygeo%dvolume(ixO^S)\}
         end select
      end if
   end do    !next iw
end do       !next idims

if (.not.slab.and.idimmin==1) call addgeometry(qdt,ixI^L,ixO^L,wCT,w,x)
call addsource2(qdt*dble(idimmax-idimmin+1)/dble(ndim), &
                                   ixI^L,ixO^L,1,nw,qtC,wCT,qt,w,x,.false.)

end subroutine centdiff
!=============================================================================
subroutine centdiff4(qdt,ixI^L,ixO^L,idim^LIM,qtC,wCT,qt,w,fC,dx^D,x)

! Advance the flow variables from t to t+qdt within ixO^L by
! fourth order centered differencing in space 
! for the dw/dt+dF_i(w)/dx_i=S type equation.
! wCT contains the time centered variables at time qtC for flux and source.
! w is the old value at qt on input and the new value at qt+qdt on output.

include 'amrvacdef.f'

integer, intent(in) :: ixI^L, ixO^L, idim^LIM
double precision, intent(in) :: qdt, qtC, qt, dx^D
double precision :: wCT(ixI^S,1:nw), w(ixI^S,1:nw)
double precision, intent(in) :: x(ixI^S,1:ndim)
double precision, dimension(ixI^S,1:ndim)             ::  xi
double precision :: fC(ixI^S,1:nwflux,1:ndim)

double precision :: v(ixG^T,ndim), f(ixG^T)

double precision, dimension(ixG^T,1:nw) :: wLC, wRC
double precision, dimension(ixG^T)      :: vLC, vRC, phi, cmaxLC, cmaxRC

double precision :: dxinv(1:ndim), dxdim
integer :: idims, iw, ix^L, hxO^L, ixC^L, jxC^L, hxC^L, kxC^L, kkxC^L, kkxR^L
logical :: transport, new_cmax, patchw(ixG^T)
!-----------------------------------------------------------------------------
! two extra layers are needed in each direction for which fluxes are added.
ix^L=ixO^L;
do idims= idim^LIM
   ix^L=ix^L^LADD2*kr(idims,^D);
end do

if (ixI^L^LTix^L|.or.|.or.) then
   call mpistop("Error in CentDiff4: Non-conforming input limits")
end if

^D&dxinv(^D)=-qdt/dx^D;

if (useprimitive) then
   ! primitive limiting:
   ! this call ensures wCT is primitive with updated auxiliaries
   call primitive(ixI^L,ixI^L,wCT,x)
endif

! Add fluxes to w
do idims= idim^LIM
   if (B0field) then
      select case (idims)
      {case (^D)
         myB0 => myB0_face^D\}
      end select
   end if

   ix^L=ixO^L^LADD2*kr(idims,^D); 
   hxO^L=ixO^L-kr(idims,^D);

   ixCmin^D=hxOmin^D; ixCmax^D=ixOmax^D;
   hxC^L=ixC^L-kr(idims,^D); 
   jxC^L=ixC^L+kr(idims,^D); 
   kxC^L=ixC^L+2*kr(idims,^D); 

   kkxCmin^D=ixImin^D; kkxCmax^D=ixImax^D-kr(idims,^D);
   kkxR^L=kkxC^L+kr(idims,^D);
   wRC(kkxC^S,1:nwflux)=wCT(kkxR^S,1:nwflux)
   wLC(kkxC^S,1:nwflux)=wCT(kkxC^S,1:nwflux)

   ! Get interface positions:
   xi(kkxC^S,1:ndim) = x(kkxC^S,1:ndim)
   xi(kkxC^S,idims) = half* ( x(kkxR^S,idims)+x(kkxC^S,idims) )
{#IFDEF STRETCHGRID
   if(idims==1) xi(kxC^S,1)=x(kxC^S,1)*(one+half*logG)
}

   dxdim=-qdt/dxinv(idims)
   call upwindLR(ixI^L,ixC^L,ixC^L,idims,wCT,wCT,wLC,wRC,x,.false.,dxdim)

   ! get auxiliaries for L and R states
   if (nwaux>0.and.(.not.(useprimitive))) then
         call getaux(.true.,wLC,xi,ixG^LL,ixC^L,'cd4_wLC')
         call getaux(.true.,wRC,xi,ixG^LL,ixC^L,'cd4_wRC')
   end if

   ! Calculate velocities from upwinded values
   new_cmax=.true.
   call getcmax(new_cmax,wLC,xi,ixG^LL,ixC^L,idims,cmaxLC,vLC,.false.)
   call getcmax(new_cmax,wRC,xi,ixG^LL,ixC^L,idims,cmaxRC,vLC,.false.)
   ! now take the maximum of left and right states
   vLC(ixC^S)=max(cmaxRC(ixC^S),cmaxLC(ixC^S))

   ! Calculate velocities for centered values
   call getv(wCT,xi,ixI^L,ix^L,idims,f)
   v(ix^S,idims)=f(ix^S)

if (useprimitive) then
   ! primitive limiting:
   ! this call ensures wCT is primitive with updated auxiliaries
   patchw(ixI^S) = .false.
   call conserve(ixI^L,ixI^L,wCT,x,patchw)
endif

   do iw=1,nwflux
      ! Get non-transported flux
      call getflux(wCT,xi,ixI^L,ix^L,iw,idims,f,transport)
      ! Add transport flux
      if (transport) f(ix^S)=f(ix^S)+v(ix^S,idims)*wCT(ix^S,iw)
      ! Center flux to interface
      ! f_i+1/2= (-f_(i+2) +7 f_(i+1) + 7 f_i - f_(i-1))/12
      fC(ixC^S,iw,idims)=(-f(kxC^S)+7.0d0*(f(jxC^S)+f(ixC^S))-f(hxC^S))/12.0d0
      ! add rempel dissipative flux, only second order version for now
      fC(ixC^S,iw,idims)=fC(ixC^S,iw,idims)-half*vLC(ixC^S) &
                                     *(wRC(ixC^S,iw)-wLC(ixC^S,iw))

      if (slab) then
         fC(ixC^S,iw,idims)=dxinv(idims)*fC(ixC^S,iw,idims)
         ! result: f_(i+1/2)-f_(i-1/2) = [-f_(i+2)+8(f_(i+1)+f_(i-1))-f_(i-2)]/12
         w(ixO^S,iw)=w(ixO^S,iw)+(fC(ixO^S,iw,idims)-fC(hxO^S,iw,idims))
      else
         select case (idims)
         {case (^D)
            fC(ixC^S,iw,^D)=-qdt*mygeo%surfaceC^D(ixC^S)*fC(ixC^S,iw,^D)
            w(ixO^S,iw)=w(ixO^S,iw)+ &
                 (fC(ixO^S,iw,^D)-fC(hxO^S,iw,^D))/mygeo%dvolume(ixO^S)\}
         end select
      end if
   end do    !next iw
end do       !next idims

if (.not.slab.and.idimmin==1) call addgeometry(qdt,ixI^L,ixO^L,wCT,w,x)
call addsource2(qdt*dble(idimmax-idimmin+1)/dble(ndim), &
                                   ixI^L,ixO^L,1,nw,qtC,wCT,qt,w,x,.false.)

end subroutine centdiff4
!=============================================================================
! end module cd
!#############################################################################
