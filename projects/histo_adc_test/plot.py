#!/usr/env python3

import numpy as np
import matplotlib.pyplot as plt

d=np.loadtxt('/home/arnaldi/pepe')                                                                  
l=np.flipud(d[2**13:])                                                                           
u=np.flipud(d[:2**13])
r=np.flipud(np.hstack((u,l)))
t=np.arange(-1,1,1/2**13)

fig,ax=plt.subplots(2,1,figsize=(10,10))
#ax.semilogy(t,r)
ax[0].semilogy(d-2**14)
ax[0].set_xlim(-2**13,2**13)
ax[0].grid()
ax[0].set_xlabel('Cuenta ADC')

ax[1].semilogy(t,r)
ax[1].set_xlim(min(t),max(t))
ax[1].grid()
ax[1].set_xlabel('Voltaje (V)')

plt.tight_layout()


plt.show()
