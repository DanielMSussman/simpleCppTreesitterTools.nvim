#ifndef TEST_H
#define TEST_H

/*!
This class...
*/
class fantasticTestClass
    {
    public:
        //constructors, destructors
        fantasticTestClass();
        ~fantasticTestClass();

        //argument and return types
        int foo(int a_b, double b, std::vector<double> &c, int b);
        float* foo2(double a, float b);
        double& foo3(std::string &message);
        std::vector<double> &foo4(int a, std::vector<double> inputVector);

        //shouldn't matter if there are non-functions scattered throughout
        double variable_Name; 

        //default arguments
        int bar(a, int b=12);

        //virtual and pure virtual functions
        virtual int baz(int a, double b=2);
        virtual std::vector<int> baz2() = 0;

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

        int variable_Name2; 

    };

/*!
This class...
*/
template<typename U>
class testClass2
    {
    public:
        //different class, same signature
        int foo(int a_b, double b, std::vector<double> &c, int b);
        //use both flavors of templates correctly
        int foo2(U &a);
        template<typename T>
        T vfoo(T a,U b);
    };

#endif
