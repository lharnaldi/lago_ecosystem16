#!/usr/env python3

import numpy as np
import matplotlib.pyplot as plt

d=np.loadtxt('/home/arnaldi/dada')                                                                  
#t=np.arange(0,1,1/2**14)

NFFT=1024
X=np.fft.fft(d,NFFT)
f=np.fft.fftfreq(NFFT,d=1/125e6)
fig,ax=plt.subplots(2,1,figsize=(10,10))
#ax.semilogy(t,r)
ax[0].plot(f[:int(d.size/2)],20*np.log10(abs(X[:int(d.size/2)])/max(abs(X[:int(d.size/2)]))))
ax[0].set_xlim(0,62.5e6)
#ax[0].set_ylim(0,50e3)
ax[0].grid()

ax[1].plot(d/2**13)
#ax[1].set_xlim(min(t),max(t))
ax[1].grid()
plt.tight_layout()


plt.show()
