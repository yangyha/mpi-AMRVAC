!=============================================================================
subroutine set_pole

include 'amrvacdef.f'
!-----------------------------------------------------------------------------
select case (typeaxial)
case ("spherical") {^IFTHREED
  ! For spherical grid, check whether phi-direction is periodic
  if(periodB(ndim)) then
    if(^PHI/=3) call mpistop("do setup.pl -phi=3 and recompile")
    if(mod(ng3(1),2)/=0) &
      call mpistop("Number of meshes in phi-direction should be even!")
    if(abs(xprobmin2)<smalldouble) then
      if(mype==0) write(unitterm,*) &
        "Will apply pi-periodic conditions at northpole!"
      poleB(1,2)=.true.
    else
      if(mype==0) write(unitterm,*) "There is no northpole!"
    end if
    if(abs(xprobmax2-dpi)<smalldouble) then
      if(mype==0) write(unitterm,*) &
        "Will apply pi-periodic conditions at southpole!"
      poleB(2,2)=.true.
    else
      if(mype==0) write(unitterm,*) "There is no southpole!"
    end if
  end if}
case ("cylindrical")
  {if (^D==^PHI.and.periodB(^D)) then
    if(mod(ng^D(1),2)/=0) &
      call mpistop("Number of meshes in phi-direction should be even!")
    if(abs(xprobmin1)<smalldouble) then
      if(mype==0) write(unitterm,*) "Will apply pi-periodic conditions at r=0"
      poleB(1,1)=.true.
    else
      if(mype==0) write(unitterm,*) "There is no cylindrical axis!"
    end if
  end if\}
end select

end subroutine set_pole
!=============================================================================
subroutine getgridgeo(igrid)

include 'amrvacdef.f'

integer, intent(in) :: igrid

integer :: ix^L, ixCoG^L, ixCoM^L, ixCo^L, ixCoCoG^L, ixGext^L
double precision :: xmin^D, dx^D
!-----------------------------------------------------------------------------
!ix^L=ixM^LL^LADD1;
ix^L=ixG^LL^LSUB1;
if (2*int(dixB/2)==dixB) then
   ixGext^L=ixG^LL;
else
   ixGext^L=ixG^LL^LADD1;
end if


allocate(pgeo(igrid)%surfaceC^D(ixmin^D-1:ixmax^D^D%ix^S), &
         pgeo(igrid)%surface^D(ixmin^D-1:ixmax^D^D%ix^S), &
         pgeo(igrid)%dvolume(ixGext^S), &
         pgeo(igrid)%x(ixGext^S,1:ndim),&
         pgeo(igrid)%dx(ixGext^S,1:ndim))

dx^D=rnode(rpdx^D_,igrid);
xmin^D=rnode(rpxmin^D_,igrid);
{#IFDEF STRETCHGRID
logG=logGs(node(plevel_,igrid))
qst=qsts(node(plevel_,igrid))
}
call fillgeo(pgeo(igrid),ixG^LL,ixGext^L,xmin^D,dx^D,.false.)

if (errorestimate==1) then
   ixCoGmin^D=1; ixCoGmax^D=ixGhi^D/2+dixB;
   if (2*int(dixB/2)==dixB) then
      ixGext^L=ixCoG^L;
   else
      ixGext^L=ixCoG^L^LADD1;
   end if
   ixCoM^L=ixCoG^L^LSUBdixB;
   ixCo^L=ixCoM^L^LADD1;
   ixCo^L=ixCoG^L^LSUB1;

   allocate(pgeoCoarse(igrid)%surfaceC^D(ixComin^D-1:ixComax^D^D%ixCo^S), &
        pgeoCoarse(igrid)%surface^D(ixComin^D-1:ixComax^D^D%ixCo^S), &
        pgeoCoarse(igrid)%dvolume(ixGext^S), &
        pgeoCoarse(igrid)%x(ixGext^S,1:ndim),&
        pgeoCoarse(igrid)%dx(ixGext^S,1:ndim))

   dx^D=two*rnode(rpdx^D_,igrid);
{#IFDEF STRETCHGRID
   logG=logGs(node(plevel_,igrid)-1)
   qst=qsts(node(plevel_,igrid)-1)
}
   call fillgeo(pgeoCoarse(igrid),ixCoG^L,ixGext^L,xmin^D,dx^D,.false.)

   ixCoCoGmin^D=1; ixCoCoGmax^D=ixCoGmax^D/2+dixB;
   if (2*int(dixB/2)==dixB) then
      ixGext^L=ixCoCoG^L;
   else
      ixGext^L=ixCoCoG^L^LADD1;
   end if


   allocate(pgeoCoCo(igrid)%dvolume(ixGext^S))

   dx^D=4.0d0*rnode(rpdx^D_,igrid);
{#IFDEF STRETCHGRID
   logG=logGs(node(plevel_,igrid)-1)
   qst=qsts(node(plevel_,igrid)-1)
   qst=qst**2
   logG=2.d0*(qst-1.d0)/(qst+1.d0)
}
   call fillgeo(pgeoCoCo(igrid),ixCoCoG^L,ixGext^L,xmin^D,dx^D,.true.)
else
   ixCoGmin^D=1; ixCoGmax^D=ixGhi^D/2+dixB;
   if (2*int(dixB/2)==dixB) then
      ixGext^L=ixCoG^L;
   else
      ixGext^L=ixCoG^L^LADD1;
   end if


   allocate(pgeoCoarse(igrid)%dvolume(ixGext^S))

   dx^D=two*rnode(rpdx^D_,igrid);
{#IFDEF STRETCHGRID
logG=logGs(node(plevel_,igrid)-1)
qst=qsts(node(plevel_,igrid)-1)
}
   call fillgeo(pgeoCoarse(igrid),ixCoG^L,ixGext^L,xmin^D,dx^D,.true.)
end if

end subroutine getgridgeo
!=============================================================================
subroutine putgridgeo(igrid)

  include 'amrvacdef.f'

integer, intent(in) :: igrid
!-----------------------------------------------------------------------------
if (errorestimate==1) then
   deallocate(pgeo(igrid)%surfaceC^D,pgeo(igrid)%surface^D,&
        pgeo(igrid)%dvolume,pgeo(igrid)%dx,pgeo(igrid)%x, &
        pgeoCoarse(igrid)%surfaceC^D,pgeoCoarse(igrid)%surface^D,&
        pgeoCoarse(igrid)%dvolume,pgeoCoarse(igrid)%dx,&
        pgeoCoCo(igrid)%dvolume)
   
else
   deallocate(pgeo(igrid)%surfaceC^D,pgeo(igrid)%surface^D,&
              pgeo(igrid)%dvolume,pgeo(igrid)%dx,pgeo(igrid)%x,pgeoCoarse(igrid)%dvolume)
end if

end subroutine putgridgeo
!=============================================================================
subroutine fillgeo(pgeogrid,ixG^L,ixGext^L,xmin^D,dx^D,need_only_volume)

include 'amrvacdef.f'

type(geoalloc) :: pgeogrid
integer, intent(in) :: ixG^L, ixGext^L
double precision, intent(in) :: xmin^D, dx^D
logical, intent(in) :: need_only_volume

integer :: idims, ix, ixM^L, ix^L, ixC^L
double precision :: x(ixGext^S,ndim) {#IFDEF STRETCHGRID ,drs(ixGext^S)}
!-----------------------------------------------------------------------------
ixM^L=ixG^L^LSUBdixB;
!ix^L=ixM^L^LADD1;
ix^L=ixG^L^LSUB1;

select case (typeaxial)
case ("slabtest")

   pgeogrid%dvolume(ixGext^S) = ^D&dx^D*

   if (need_only_volume) return

   ixCmin^D=ixmin^D-kr(^D,1); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC1(ixC^S)={^IFONED one}{^NOONED dx2}{^IFTHREED*dx3}
   pgeogrid%surface1(ixC^S) ={^IFONED one}{^NOONED dx2}{^IFTHREED*dx3}
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC2(ixC^S)=dx1}{^IFTHREED*dx3}
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   pgeogrid%surface2(ixC^S)=dx1}{^IFTHREED*dx3}
   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC3(ixC^S)=dx1*dx2
   pgeogrid%surface3(ixC^S)=dx1*dx2}

   ^D&pgeogrid%dx(ixGext^S,^D)=dx^D;


case ("spherical")

   do idims=1,min(ndim,2)
      select case(idims)
      {case(^D)
         do ix = ixGext^LIM^D
            x(ix^D%ixGext^S,^D)=xmin^D+(dble(ix-dixB)-half)*dx^D
         end do\}
      end select
   end do
{#IFDEF STRETCHGRID
   do ix = ixGext^LIM1
      x(ix,ixGext^SE,1)=(xmin1/(one-half*logG))*qst**(ix-dixB-1)
   end do
   drs(ixGext^S)=x(ixGext^S,1)*logG
}
{#IFNDEF STRETCHGRID
   if(typespherical==0) then
     pgeogrid%dvolume(ixGext^S)=(x(ixGext^S,1)**2+dx1**2/12.0d0)*dx1 {^NOONED &
              *two*dabs(dsin(x(ixGext^S,2)))*dsin(half*dx2)}{^IFTHREED*dx3}
   else
     pgeogrid%dvolume(ixGext^S)=(x(ixGext^S,1)**2)*dx1 {^NOONED &
              *dabs(dsin(x(ixGext^S,2)))*dx2}{^IFTHREED*dx3}
   endif
}
{#IFDEF STRETCHGRID
   if(typespherical==0) then
     pgeogrid%dvolume(ixGext^S)=(x(ixGext^S,1)**2+drs(ixGext^S)**2/12.0d0)*&
               drs(ixGext^S){^NOONED &
              *two*dabs(dsin(x(ixGext^S,2)))*dsin(half*dx2)}{^IFTHREED*dx3}
   else
     pgeogrid%dvolume(ixGext^S)=(x(ixGext^S,1)**2)*drs(ixGext^S){^NOONED &
              *dabs(dsin(x(ixGext^S,2)))*dx2}{^IFTHREED*dx3}
   endif
}

   if (need_only_volume) return

   pgeogrid%x(ixGext^S,1:ndim)=x(ixGext^S,1:ndim)

   ixCmin^D=ixmin^D-kr(^D,1); ixCmax^D=ixmax^D;
{#IFNDEF STRETCHGRID
   if(typespherical==0) then
       pgeogrid%surfaceC1(ixC^S)=(x(ixC^S,1)+half*dx1)**2 {^NOONED &
              *two*dsin(x(ixC^S,2))*dsin(half*dx2)}{^IFTHREED*dx3}
   else
       pgeogrid%surfaceC1(ixC^S)=(x(ixC^S,1)+half*dx1)**2 {^NOONED &
              *dsin(x(ixC^S,2))*dx2}{^IFTHREED*dx3}
   endif

   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC2(ixC^S)=x(ixC^S,1)*dx1 &
              *dsin(x(ixC^S,2)+half*dx2)}{^IFTHREED*dx3}

   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC3(ixC^S)=x(ixC^S,1)*dx1*dx2}
}
{#IFDEF STRETCHGRID
   if(typespherical==0) then
       pgeogrid%surfaceC1(ixC^S)=(x(ixC^S,1)+half*drs(ixC^S))**2 {^NOONED &
              *two*dsin(x(ixC^S,2))*dsin(half*dx2)}{^IFTHREED*dx3}
   else
       pgeogrid%surfaceC1(ixC^S)=(x(ixC^S,1)+half*drs(ixC^S))**2 {^NOONED &
              *dsin(x(ixC^S,2))*dx2}{^IFTHREED*dx3}
   endif

   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC2(ixC^S)=x(ixC^S,1)*drs(ixC^S)&
              *dsin(x(ixC^S,2)+half*dx2)}{^IFTHREED*dx3}

   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   pgeogrid%surfaceC3(ixC^S)=x(ixC^S,1)*drs(ixC^S)*dx2}
}

   ixCmin^D=ixmin^D-kr(^D,1); ixCmax^D=ixmax^D;
   if(typespherical==0) then
       pgeogrid%surface1(ixC^S)=x(ixC^S,1)**2 {^NOONED &
              *two*dsin(x(ixC^S,2))*dsin(half*dx2)}{^IFTHREED*dx3}
   else
      pgeogrid%surface1(ixC^S)=x(ixC^S,1)**2 {^NOONED &
              *dsin(x(ixC^S,2))*dx2}{^IFTHREED*dx3}
   endif

{#IFNDEF STRETCHGRID
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   pgeogrid%surface2(ixC^S)=x(ixC^S,1)*dx1 &
              *dsin(x(ixC^S,2))}{^IFTHREED*dx3}

   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   pgeogrid%surface3(ixC^S)=x(ixC^S,1)*dx1*dx2}

   pgeogrid%dx(ixGext^S,1)=dx1
}
{#IFDEF STRETCHGRID
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   pgeogrid%surface2(ixC^S)=x(ixC^S,1)*drs(ixC^S)&
              *dsin(x(ixC^S,2))}{^IFTHREED*dx3}

   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   pgeogrid%surface3(ixC^S)=x(ixC^S,1)*drs(ixC^S)*dx2}

   pgeogrid%dx(ixGext^S,1)=drs(ixGext^S)
}
   {^NOONED pgeogrid%dx(ixGext^S,2)=x(ixGext^S,1)*dx2}
   {^IFTHREED pgeogrid%dx(ixGext^S,3)=x(ixGext^S,1)*dsin(x(ixGext^S,2))*dx3}

case ("cylindrical")

{#IFNDEF STRETCHGRID
   do ix = ixGext^LIM1
      x(ix,ixGext^SE,1)=xmin1+(dble(ix-dixB)-half)*dx1
   end do

   pgeogrid%dvolume(ixGext^S)=dabs(half*((x(ixGext^S,1)+half*dx1)**2-(x(ixGext^S,1)-half*dx1)**2)){^DE&*dx^DE }
}
{#IFDEF STRETCHGRID
   do ix = ixGext^LIM1
      x(ix,ixGext^SE,1)=(xmin1/(one-half*logG))*qst**(ix-dixB-1)
   end do
   drs(ixGext^S)=x(ixGext^S,1)*logG
   pgeogrid%dvolume(ixGext^S)=dabs(half*&
        ((x(ixGext^S,1)+half*drs(ixGext^S))**2-&
         (x(ixGext^S,1)-half*drs(ixGext^S))**2)){^DE&*dx^DE }
}

   if (need_only_volume) return

   pgeogrid%x(ixGext^S,1)=x(ixGext^S,1)

   ixCmin^D=ixmin^D-kr(^D,1); ixCmax^D=ixmax^D;
{#IFNDEF STRETCHGRID
   pgeogrid%surfaceC1(ixC^S)=dabs(x(ixC^S,1)+half*dx1){^DE&*dx^DE }
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   if (^Z==2) pgeogrid%surfaceC2(ixC^S)=x(ixC^S,1)*dx1{^IFTHREED*dx3}
   if (^PHI==2) pgeogrid%surfaceC2(ixC^S)=dx1{^IFTHREED*dx3}}
   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   if (^Z==3) pgeogrid%surfaceC3(ixC^S)=x(ixC^S,1)*dx1*dx2
   if (^PHI==3) pgeogrid%surfaceC3(ixC^S)=dx1*dx2}

   ixCmin^D=ixmin^D-kr(^D,1); ixCmax^D=ixmax^D;
   !!pgeogrid%surface1(ixC^S)=x(ixC^S,1){^DE&*dx^DE }
   pgeogrid%surface1(ixC^S)=dabs(x(ixC^S,1)){^DE&*dx^DE }
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   if (^Z==2) pgeogrid%surface2(ixC^S)=x(ixC^S,1)*dx1{^IFTHREED*dx3}
   if (^PHI==2) pgeogrid%surface2(ixC^S)=dx1{^IFTHREED*dx3}}
   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   if (^Z==3) pgeogrid%surface3(ixC^S)=x(ixC^S,1)*dx1*dx2
   if (^PHI==3) pgeogrid%surface3(ixC^S)=dx1*dx2}


   pgeogrid%dx(ixGext^S,1)=dx1
}
{#IFDEF STRETCHGRID
   pgeogrid%surfaceC1(ixC^S)=dabs(x(ixC^S,1)+half*drs(ixC^S)){^DE&*dx^DE }
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   if (^Z==2) pgeogrid%surfaceC2(ixC^S)=x(ixC^S,1)*drs(ixC^S){^IFTHREED*dx3}
   if (^PHI==2) pgeogrid%surfaceC2(ixC^S)=drs(ixC^S){^IFTHREED*dx3}}
   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   if (^Z==3) pgeogrid%surfaceC3(ixC^S)=x(ixC^S,1)*drs(ixC^S)*dx2
   if (^PHI==3) pgeogrid%surfaceC3(ixC^S)=drs(ixC^S)*dx2}

   ixCmin^D=ixmin^D-kr(^D,1); ixCmax^D=ixmax^D;
   !!pgeogrid%surface1(ixC^S)=x(ixC^S,1){^DE&*dx^DE }
   pgeogrid%surface1(ixC^S)=dabs(x(ixC^S,1)){^DE&*dx^DE }
   {^NOONED
   ixCmin^D=ixmin^D-kr(^D,2); ixCmax^D=ixmax^D;
   if (^Z==2) pgeogrid%surface2(ixC^S)=x(ixC^S,1)*drs(ixC^S){^IFTHREED*dx3}
   if (^PHI==2) pgeogrid%surface2(ixC^S)=drs(ixC^S){^IFTHREED*dx3}}
   {^IFTHREED
   ixCmin^D=ixmin^D-kr(^D,3); ixCmax^D=ixmax^D;
   if (^Z==3) pgeogrid%surface3(ixC^S)=x(ixC^S,1)*drs(ixC^S)*dx2
   if (^PHI==3) pgeogrid%surface3(ixC^S)=drs(ixC^S)*dx2}


   pgeogrid%dx(ixGext^S,1)=drs(ixGext^S)
}
   {^IFZ {^DE&if (^DE==^Z) pgeogrid%dx(ixGext^S,^DE)=dx^DE\}}
   {^IFPHI {if (^DE==^PHI) pgeogrid%dx(ixGext^S,^DE)=x(ixGext^S,1)*dx^DE\}}


case default

   call mpistop("Sorry, typeaxial unknown")
   
end select

end subroutine fillgeo
!=============================================================================
subroutine gradient(q,ixI^L,ix^L,idir,gradq)

! Calculate gradient of a scalar q within ixL in direction idir

include 'amrvacdef.f'

integer :: ixI^L, ix^L, idir
double precision :: q(ixI^S), gradq(ixI^S)

double precision :: qC(ixI^S),invdx
integer :: jx^L, hx^L, ixC^L, jxC^L {#IFDEF FOURTHORDER , lx^L, kx^L}

!-----------------------------------------------------------------------------

invdx=1.d0/dxlevel(idir)
if (slab) then
{#IFNDEF FOURTHORDER
   jx^L=ix^L+kr(idir,^D);
   hx^L=ix^L-kr(idir,^D);
   gradq(ix^S) = half*(q(jx^S)-q(hx^S))*invdx
}{#IFDEF FOURTHORDER
   lx^L=ix^L+2*kr(idir,^D);
   jx^L=ix^L+kr(idir,^D);
   hx^L=ix^L-kr(idir,^D);
   kx^L=ix^L-2*kr(idir,^D);
   gradq(ix^S) = (-q(lx^S) + 8.0d0 * q(jx^S) - 8.0d0 * q(hx^S) + q(kx^S)) &
        /(12.0d0 * dxlevel(idir))
}
else
   hx^L=ix^L-kr(idir,^D);
   ixCmin^D=hxmin^D;ixCmax^D=ixmax^D;
   jxC^L=ixC^L+kr(idir,^D);
   select case(idir)
   {case(^D)
      qC(ixC^S)=mygeo%surfaceC^D(ixC^S)*half*(q(ixC^S)+q(jxC^S))
      gradq(ix^S)=(qC(ix^S)-qC(hx^S))/mygeo%dvolume(ix^S)
      ! Substract difference divergence and gradient
      !gradq(ix^S)=gradq(ix^S)-q(ix^S) &
      !               *(mygeo%surfaceC^D(ix^S)-mygeo%surfaceC^D(hx^S)) &
      !              /mygeo%dvolume(ix^S) \}
   end select
end if

end subroutine gradient
!=============================================================================
subroutine gradientS(q,ixI^L,ix^L,idir,gradq)

! Calculate gradient of a scalar q within ixL in direction idir
! first use limiter to go from cell center to edge

include 'amrvacdef.f'

integer :: ixI^L, ix^L, idir
double precision :: q(ixI^S), gradq(ixI^S)
double precision :: dxdim

double precision :: qC(ixI^S)
double precision,dimension(ixI^S):: qL,qR,dqC,ldq,invdx
integer                          :: hx^L,ixC^L,jxC^L,gxC^L,hxC^L,idummy
character*79 :: savetypelimiter,savetypegradlimiter,save2typelimiter
!-----------------------------------------------------------------------------

invdx=1.d0/dxlevel(idir)
hx^L=ix^L-kr(idir,^D);
ixCmin^D=hxmin^D;ixCmax^D=ixmax^D;
jxC^L=ixC^L+kr(idir,^D);
gxCmin^D=ixCmin^D-kr(idir,^D);gxCmax^D=jxCmax^D;
hxC^L=gxC^L+kr(idir,^D);
idummy=0

savetypelimiter=typelimiter
savetypegradlimiter=typegradlimiter
! set the gradient limiter here
typelimiter=typegradlimiter
qR(gxC^S) = q(hxC^S)
qL(gxC^S) = q(gxC^S)
if (typelimiter/='ppm') then
   dqC(gxC^S)= qR(gxC^S)-qL(gxC^S)
   save2typelimiter=typelimiter
   if(save2typelimiter=='koren') typelimiter='korenL'
   if(save2typelimiter=='cada')  typelimiter='cadaL'
   if(save2typelimiter=='cada3') typelimiter='cada3L'
   dxdim=dxlevel(idir)
   call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idir,ldq,dxdim)
   qL(ixC^S) = qL(ixC^S) + half*ldq(ixC^S)
   if(save2typelimiter=='koren')then
     typelimiter='korenR'
     call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idir,ldq,dxdim)
   endif
   if(save2typelimiter=='cada')then
     typelimiter='cadaR'
     call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idir,ldq,dxdim)
   endif
   if(save2typelimiter=='cada3')then
     typelimiter='cada3R'
     call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idir,ldq,dxdim)
   endif
   typelimiter=save2typelimiter
   qR(ixC^S) = qR(ixC^S) - half*ldq(jxC^S)
else
   call PPMlimitervar(ixG^LL,ixM^LL,idir,q,q,qL,qR)
endif
! set the method limiter back
typelimiter=savetypelimiter
typegradlimiter=savetypegradlimiter

if (slab) then
   gradq(ix^S)=half*(qR(ix^S)-qL(hx^S))*invdx
else
   select case(idir)
   {case(^D)
    gradq(ix^S)=(qR(ix^S)-qL(hx^S))/mygeo%dx(ix^S,idir) \}
   end select
end if

end subroutine gradientS
!=============================================================================
subroutine divvector(qvec,ixI^L,ixO^L,divq)

! Calculate divergence of a vector qvec within ixL

include 'amrvacdef.f'

integer :: ixI^L,ixO^L
double precision :: qvec(ixI^S,1:ndir), divq(ixI^S)

double precision :: qC(ixI^S), invdx(1:ndim)
integer :: jxO^L, hxO^L, ixC^L, jxC^L, idims, ix^L {#IFDEF FOURTHORDER , gxO^L, kxO^L}
!-----------------------------------------------------------------------------
{#IFNDEF FOURTHORDER
ix^L=ixO^L^LADD1;
}{#IFDEF FOURTHORDER
ix^L=ixO^L^LADD2;
}
if (ixImin^D>ixmin^D.or.ixImax^D<ixmax^D|.or.) &
   call mpistop("Error in divvector: Non-conforming input limits")
invdx=1.d0/dxlevel
divq(ixO^S)=zero
if (slab) then
  do idims=1,ndim
{#IFNDEF FOURTHORDER
     jxO^L=ixO^L+kr(idims,^D);
     hxO^L=ixO^L-kr(idims,^D);
     divq(ixO^S)=divq(ixO^S)+half*(qvec(jxO^S,idims)-qvec(hxO^S,idims))*invdx(idims)
}{#IFDEF FOURTHORDER
     kxO^L=ixO^L+2*kr(idims,^D);
     jxO^L=ixO^L+kr(idims,^D);
     hxO^L=ixO^L-kr(idims,^D);
     gxO^L=ixO^L-2*kr(idims,^D);
     divq(ixO^S)=divq(ixO^S)+&
          (-qvec(kxO^S,idims) + 8.0d0 * qvec(jxO^S,idims) - 8.0d0 * qvec(hxO^S,idims) + qvec(gxO^S,idims))/(12.0d0 * dxlevel(idims))
}
  end do
else
  do idims=1,ndim
     hxO^L=ixO^L-kr(idims,^D);
     ixCmin^D=hxOmin^D;ixCmax^D=ixOmax^D;
     jxC^L=ixC^L+kr(idims,^D);
     select case(idims)
     {case(^D)
        qC(ixC^S)=mygeo%surfaceC^D(ixC^S)*half*(qvec(ixC^S,idims)+qvec(jxC^S,idims))
        divq(ixO^S)=divq(ixO^S)+qC(ixO^S)-qC(hxO^S) \}
      end select
  end do
  divq(ixO^S)=divq(ixO^S)/mygeo%dvolume(ixO^S)
end if


end subroutine divvector 
!=============================================================================
subroutine curlvector(qvec,ixI^L,ixO^L,curlvec,idirmin,idirmin0,ndir0)

! Calculate curl of a vector qvec within ixL

include 'amrvacdef.f'

integer :: ixI^L,ixO^L,idirmin,ix^L,idir,jdir,kdir,hxO^L,jxO^L,ndir0,idirmin0
double precision :: qvec(ixI^S,1:ndir0),curlvec(ixI^S,idirmin0:3), invdx(1:ndim)
double precision :: tmp(ixI^S),tmp2(ixI^S),surface(ixI^S),mydx(ixI^S){#IFDEF FOURTHORDER , gxO^L, kxO^L}
!-----------------------------------------------------------------------------
{#IFNDEF FOURTHORDER
ix^L=ixO^L^LADD1;
}{#IFDEF FOURTHORDER
ix^L=ixO^L^LADD2;
}
if (ixImin^D>ixmin^D.or.ixImax^D<ixmax^D|.or.) &
   call mpistop("Error in curl: Non-conforming input limits")

! Calculate curl within ixL: CurlV_i=eps_ijk*d_j V_k
! Curl can have components (idirmin0:3)
! Determine exact value of idirmin while doing the loop.

invdx=1.d0/dxlevel
idirmin=4
curlvec(ixO^S,idirmin0:3)=zero

do idir=idirmin0,3; do jdir=1,ndim; do kdir=1,ndir0
   if(lvc(idir,jdir,kdir)/=0)then
      tmp(ix^S)=qvec(ix^S,kdir)
      hxO^L=ixO^L-kr(jdir,^D);
      jxO^L=ixO^L+kr(jdir,^D);
      select case(typeaxial)
        case('slab')
{#IFDEF FOURTHORDER
         kxO^L=ixO^L+2*kr(jdir,^D);
         gxO^L=ixO^L-2*kr(jdir,^D);
         tmp2(ixO^S)=(-tmp(kxO^S) + 8.0d0 * tmp(jxO^S) - 8.0d0 * tmp(hxO^S) + tmp(gxO^S)) &
           / (12.0d0 * dxlevel(jdir))
}
{#IFNDEF FOURTHORDER
         tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))*invdx(jdir)
}
        case('spherical')
         select case(jdir)
            case(1)
             tmp(ixI^S)=tmp(ixI^S)*mygeo%x(ixI^S,1)
             tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))/(mygeo%x(ixO^S,1)*mygeo%dx(ixO^S,1))
   {^NOONED case(2)
             mydx(ixO^S)=mygeo%dx(ixO^S,2)
             if(idir==1) then
                tmp(ixI^S)=tmp(ixI^S)*dsin(mygeo%x(ixI^S,2))
                mydx(ixO^S)=dsin(mygeo%x(ixO^S,2))*mydx(ixO^S)
             endif
             tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))/mydx(ixO^S)}
 {^IFTHREED case(3)
             tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))/mygeo%dx(ixO^S,3)}
         end select
        case('cylindrical')
         if(^Z==3) then
           select case(jdir)
              case(1)
               mydx(ixO^S)=mygeo%dx(ixO^S,1)
               if(idir==3) then
                  tmp(ixI^S)=tmp(ixI^S)*mygeo%x(ixI^S,1)
                  mydx(ixO^S)=mygeo%x(ixO^S,1)*mydx(ixO^S)
               endif
               tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))/mydx(ixO^S)
     {^NOONED case(2)
               tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))/mygeo%dx(ixO^S,2)}
   {^IFTHREED case(3)
               tmp2(ixO^S)=half*(tmp(jxO^S)-tmp(hxO^S))/mygeo%dx(ixO^S,3)}
           end select
         end if
         if(^PHI==3) then
           select case(jdir)
              case(1)
               mydx(ixO^S)=mygeo%dx(ixO^S,1)
               if(idir==2) then
                  tmp(ixI^S)=tmp(ixI^S)*mygeo%x(ixI^S,1)
                  mydx(ixO^S)=mygeo%x(ixO^S,1)*mydx(ixO^S)
               endif
               tmp2(ixO^S)=-half*(tmp(jxO^S)-tmp(hxO^S))/mydx(ixO^S)
     {^NOONED case(2)
               tmp2(ixO^S)=-half*(tmp(jxO^S)-tmp(hxO^S))/mygeo%dx(ixO^S,2)}
   {^IFTHREED case(3)
               tmp2(ixO^S)=-half*(tmp(jxO^S)-tmp(hxO^S))/mygeo%dx(ixO^S,3)}
           end select
         end if
      end select
      if(lvc(idir,jdir,kdir)==1)then
         curlvec(ixO^S,idir)=curlvec(ixO^S,idir)+tmp2(ixO^S)
      else
         curlvec(ixO^S,idir)=curlvec(ixO^S,idir)-tmp2(ixO^S)
      endif
      if(idir<idirmin)idirmin=idir
   endif
enddo; enddo; enddo;

end subroutine curlvector 
!=============================================================================
subroutine divvectorS(qvec,ixI^L,ixO^L,divq)

! Calculate divergence of a vector qvec within ixL
! using limited extrapolation to cell edges

include 'amrvacdef.f'

integer :: ixI^L,ixO^L
double precision :: qvec(ixG^T,1:ndir), divq(ixG^T)

double precision,dimension(ixG^T):: qL,qR,dqC,ldq
double precision :: dxdim, invdx(1:ndim)

integer :: hxO^L,ixC^L,jxC^L,idims,ix^L,gxC^L,hxC^L,idummy
character*79, save :: savetypelimiter,savetypegradlimiter,save2typelimiter
!-----------------------------------------------------------------------------
ix^L=ixO^L^LADD2;

if (ixImin^D>ixmin^D.or.ixImax^D<ixmax^D|.or.) &
   call mpistop("Error in divvectorS: Non-conforming input limits")

idummy=0
invdx=1.d0/dxlevel
divq(ixO^S)=zero
do idims=1,ndim
   hxO^L=ixO^L-kr(idims,^D);
   ixCmin^D=hxOmin^D;ixCmax^D=ixOmax^D;
   jxC^L=ixC^L+kr(idims,^D);
   gxCmin^D=ixCmin^D-kr(idims,^D);gxCmax^D=jxCmax^D;
   hxC^L=gxC^L+kr(idims,^D);
   savetypelimiter=typelimiter
   savetypegradlimiter=typegradlimiter
   ! set the gradient limiter here
   typelimiter=savetypegradlimiter
  !! {if(gxCmin^D<ixGlo1)then
  !!   gxCmin^D=ixGlo1
  !!   hxCmin^D=hxCmin^D+1
  !! endif \}
  !! {if(hxCmax^D>ixGhi1)then
  !!   hxCmax^D=ixGhi1
  !!   gxCmax^D=gxCmax^D-1
  !! endif \}
   qR(gxC^S) = qvec(hxC^S,idims)
   qL(gxC^S) = qvec(gxC^S,idims)
   if(typelimiter/='ppm') then
      dqC(gxC^S)= qR(gxC^S)-qL(gxC^S)
      save2typelimiter=typelimiter
      if(save2typelimiter=='koren') typelimiter='korenL'
      if(save2typelimiter=='cada')  typelimiter='cadaL'
      if(save2typelimiter=='cada3') typelimiter='cada3L'
      dxdim=dxlevel(idims)
      call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idims,ldq,dxdim)
      qL(ixC^S) = qL(ixC^S) + half*ldq(ixC^S)
      if(save2typelimiter=='koren')then
         typelimiter='korenR'
         call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idims,ldq,dxdim)
       endif
      if(save2typelimiter=='cada')then
         typelimiter='cadaR'
         call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idims,ldq,dxdim)
       endif
      if(save2typelimiter=='cada3')then
         typelimiter='cada3R'
         call dwlimiter2(dqC,ixI^L,gxC^L,idummy,idims,ldq,dxdim)
       endif
       typelimiter=save2typelimiter
      qR(ixC^S) = qR(ixC^S) - half*ldq(jxC^S)
   else if (typelimiter .eq. 'ppm') then
      dqC(ixI^S)=qvec(ixI^S,idims)
      call PPMlimitervar(ixG^LL,ixM^LL,idims,dqC,dqC,qL,qR)
   else
      call mpistop('typelimiter unknown in divvectorS')
   endif
   ! set the method limiter back
   typegradlimiter=typelimiter
   typelimiter=savetypelimiter

   if (slab) then
     divq(ixO^S)=divq(ixO^S)+half*(qR(ixO^S)-qL(hxO^S))*invdx(idims)
   else
     select case(idims)
     {case(^D)
        qR(ixC^S)=mygeo%surfaceC^D(ixC^S)*qR(ixC^S)
        qL(ixC^S)=mygeo%surfaceC^D(ixC^S)*qL(ixC^S)
        divq(ixO^S)=divq(ixO^S)+qR(ixO^S)-qL(hxO^S) \}
      end select
   end if
end do
if(.not.slab) divq(ixO^S)=divq(ixO^S)/mygeo%dvolume(ixO^S)

end subroutine divvectorS
!=============================================================================
subroutine extremaq(ixI^L,ixO^L,q,nshift,qMax,qMin)

include 'amrvacdef.f'

integer,intent(in)           :: ixI^L,ixO^L
double precision, intent(in) :: q(ixI^S)
integer,intent(in)           :: nshift

double precision, intent(out) :: qMax(ixI^S),qMin(ixI^S)

integer           :: ixs^L,ixsR^L,ixsL^L,idims,jdims,kdims,ishift,i,j 
!-------------------------------------------------------------------------
do ishift=1,nshift
 idims=1
 ixsR^L=ixO^L+ishift*kr(idims,^D);
 ixsL^L=ixO^L-ishift*kr(idims,^D);
 if (ishift==1) then
   qMax(ixO^S)=max(q(ixO^S),q(ixsR^S),q(ixsL^S))
   qMin(ixO^S)=min(q(ixO^S),q(ixsR^S),q(ixsL^S))
 else
   qMax(ixO^S)=max(qMax(ixO^S),q(ixsR^S),q(ixsL^S))
   qMin(ixO^S)=min(qMin(ixO^S),q(ixsR^S),q(ixsL^S))
 end if
 {^NOONED
 idims=1
 jdims=idims+1
 do i=-1,1
   ixs^L=ixO^L+i*ishift*kr(idims,^D);
   ixsR^L=ixs^L+ishift*kr(jdims,^D);
   ixsL^L=ixs^L-ishift*kr(jdims,^D);
   qMax(ixO^S)=max(qMax(ixO^S),q(ixsR^S),q(ixsL^S))
   qMin(ixO^S)=min(qMin(ixO^S),q(ixsR^S),q(ixsL^S))
 end do
 }
 {^IFTHREED
 idims=1
 jdims=idims+1
 kdims=jdims+1
 do i=-1,1
   ixs^L=ixO^L+i*ishift*kr(idims,^D);
   do j=-1,1
      ixs^L=ixO^L+j*ishift*kr(jdims,^D);
      ixsR^L=ixs^L+ishift*kr(kdims,^D);
      ixsL^L=ixs^L-ishift*kr(kdims,^D);
      qMax(ixO^S)=max(qMax(ixO^S),q(ixsR^S),q(ixsL^S))
      qMin(ixO^S)=min(qMin(ixO^S),q(ixsR^S),q(ixsL^S))
   end do
 end do
 }
enddo

end subroutine  extremaq
!=============================================================================
subroutine extremaw(ixI^L,ixO^L,w,nshift,wMax,wMin)

include 'amrvacdef.f'

integer,intent(in)            :: ixI^L,ixO^L
double precision, intent(in)  :: w(ixI^S,1:nw)
integer,intent(in)            :: nshift

double precision, intent(out) :: wMax(ixI^S,1:nwflux),wMin(ixI^S,1:nwflux)

integer          :: ixs^L,ixsR^L,ixsL^L,idims,jdims,kdims,ishift,i,j
!-------------------------------------------------------------------------
do ishift=1,nshift
 idims=1
 ixsR^L=ixO^L+ishift*kr(idims,^D);
 ixsL^L=ixO^L-ishift*kr(idims,^D);
 if (ishift==1) then
    wMax(ixO^S,1:nwflux)= &
     max(w(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
    wMin(ixO^S,1:nwflux)= &
     min(w(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
 else
    wMax(ixO^S,1:nwflux)= &
     max(wMax(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
    wMin(ixO^S,1:nwflux)= &
     min(wMin(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
 end if
 {^NOONED
 idims=1
 jdims=idims+1
 do i=-1,1
   ixs^L=ixO^L+i*ishift*kr(idims,^D);
   ixsR^L=ixs^L+ishift*kr(jdims,^D);
   ixsL^L=ixs^L-ishift*kr(jdims,^D);
   wMax(ixO^S,1:nwflux)= &
     max(wMax(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
   wMin(ixO^S,1:nwflux)= &
     min(wMin(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
 end do
 }
 {^IFTHREED
 idims=1
 jdims=idims+1
 kdims=jdims+1
 do i=-1,1
   ixs^L=ixO^L+i*ishift*kr(idims,^D);
   do j=-1,1
      ixs^L=ixO^L+j*ishift*kr(jdims,^D);
      ixsR^L=ixs^L+ishift*kr(kdims,^D);
      ixsL^L=ixs^L-ishift*kr(kdims,^D);
      wMax(ixO^S,1:nwflux)= &
       max(wMax(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
      wMin(ixO^S,1:nwflux)= &
       min(wMin(ixO^S,1:nwflux),w(ixsR^S,1:nwflux),w(ixsL^S,1:nwflux))
   end do
 end do
 }
enddo

end subroutine  extremaw
!=============================================================================
subroutine extremaa(ixI^L,ixO^L,a,nshift,aMin)

include 'amrvacdef.f'

integer,intent(in)           :: ixI^L,ixO^L
double precision, intent(in) :: a(ixI^S)
integer,intent(in)           :: nshift

double precision, intent(out) :: aMin(ixI^S)

integer          :: ixs^L,ixsR^L,ixsL^L,idims,jdims,kdims,ishift,i,j
!-------------------------------------------------------------------------
do ishift=1,nshift
  idims=1
  ixsR^L=ixO^L+ishift*kr(idims,^D);
  ixsL^L=ixO^L-ishift*kr(idims,^D);
  aMin(ixO^S)=min(a(ixsR^S),a(ixO^S),a(ixsL^S))
  {^NOONED
  idims=1
  jdims=idims+1
  do i=-1,1
    ixs^L=ixO^L+i*ishift*kr(idims,^D);
    ixsR^L=ixs^L+ishift*kr(jdims,^D);
    ixsL^L=ixs^L-ishift*kr(jdims,^D);
    aMin(ixO^S)=min(aMin(ixO^S),a(ixsR^S),a(ixsL^S))
  end do
  }
  {^IFTHREED
  idims=1
  jdims=idims+1
  kdims=jdims+1
  do i=-1,1
   ixs^L=ixO^L+i*ishift*kr(idims,^D);
   do j=-1,1
      ixs^L=ixO^L+j*ishift*kr(jdims,^D);
      ixsR^L=ixs^L+ishift*kr(kdims,^D);
      ixsL^L=ixs^L-ishift*kr(kdims,^D);
      aMin(ixO^S)=min(aMin(ixO^S),a(ixsR^S),a(ixsL^S))
   end do
  end do
  }
end do

end subroutine extremaa
!=============================================================================
subroutine locate_in_table(xpoint,table,nxtp,ixtp,res)
!  Fast search table to find xpoint's location in the table
!  record the distance between xpoint and the its cloest element table(ixtp)
! INPUT:
!  xpoint : the point you want to locate in the table
!  table : 1D table you want to find location in
!  nxtp : number of elements in the table
! OUTPUT:
!  ixtp : closest element's index in table
!  res : offset(distance) from the closest element in table
include 'amrvacdef.f'

integer, intent(in) :: nxtp
double precision,intent(in)   :: xpoint,table(nxtp)
double precision, intent(out) :: res
integer, intent(out) :: ixtp

integer :: jl,jc,jh
!-----------------------------------------------------------------------------
if(xpoint < table(1)) then
  ixtp=1
  res=(xpoint-table(1))/(table(2)-table(1))
else if (xpoint > table(nxtp)) then
  ixtp=nxtp
  res=(xpoint-table(nxtp))/(table(nxtp)-table(nxtp-1))
else
  jl=0
  jh=nxtp+1
  do
    if (jh-jl <= 1) exit
    jc=(jh+jl)/2
    if (xpoint >= table(jc)) then
        jl=jc
    else
        jh=jc
    end if
  end do
  res=(xpoint-table(jh-1))/(table(jh)-table(jh-1))
  if(res<=0.5d0) then
    ixtp=jh-1
  else
    ixtp=jh
    res=res-1.d0
  endif
end if
end subroutine locate_in_table
!=============================================================================
