#ifndef DERIVEDCLASS_H
#define DERIVEDCLASS_H

#include "implementClassTest.h"

/*!
This class, inheriting from fantasticClass, ...
*/
class derivedClass : public fantasticClass
    {
    public:

        virtual int virtualBaz(int a, double b=2);

        virtual std::vector<int> pureVirtualBaz2();

    };

#endif
