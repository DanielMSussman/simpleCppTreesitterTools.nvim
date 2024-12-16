#ifndef IMPLEMENTCLASSTEST_H
#define IMPLEMENTCLASSTEST_H

/*!
This class...
*/
class fantasticClass
    {
    public:
        fantasticClass();
        ~fantasticClass();

        //argument and return types
        int foo(int a_b, double b, std::vector<double> &c, int b);

        int& foo1(double *c);

        float* foo2(double a, float b);
        double& foo3(std::string &message);
        std::vector<double> &foo4(int a, std::vector<double> inputVector);

        //shouldn't matter if there are non-functions scattered throughout
        double variable_Name; 

        //default arguments in the parameter list
        int bar(a, int b=12);

        //virtual and pure virtual functions
        virtual int virtualBaz(int a, double b=2);
        virtual std::vector<int> pureVirtualBaz2() = 0;

        //don't include functions that are defined in the header
        void definedInClass(int a)
            {
            variable_Name2 = a;
            };

        //templated functions
        template<typename T>
        T vfoo(T a,double b);

        //static functions
        static double staticTest(std::vector<int> &a);

    //access specifiers shouldn't matter at all
    private:

        // custom / unknown datatype
        vector3 *returnVector(std::vector<float> &a, vector3 b);

        //constness and constexpr
        int cTest(double a , const int b) const;
        constexpr int cTest2(const int a);
        constexpr int cTest3(const int a) const;
        template<typename T>
        T vfoo(T a,double b,customType c) const;
    };

#endif
