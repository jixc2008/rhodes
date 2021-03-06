#pragma once

namespace rho{
namespace common{

struct IRhoRunnable
{
    enum EPriority{ epNormal = 0, epHigh, epLow};

    virtual void run() = 0;
};

struct IRhoThreadImpl
{
    virtual ~IRhoThreadImpl(void){}

    virtual void start(IRhoRunnable* pRunnable, IRhoRunnable::EPriority ePriority) = 0;
    virtual void stop(unsigned int nTimeoutToKill) = 0;
    virtual void wait(unsigned int nTimeout) = 0;
    virtual void stopWait() = 0;
};

}
}
