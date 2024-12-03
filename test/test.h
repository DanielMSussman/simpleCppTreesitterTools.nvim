#ifndef TEST_H
#define TEST_H

/*!
This class...
*/
class classNamed
    {
    public:
        //constructors, destructors
        classNamed();
        ~classNamed();

        //argument and return types
        int foo(int a_b, double b, std::vector<double> &c, int b);
        float* foo2(double a, float b);
        double& foo3(std::string &message);
        std::vector<double> &foo4(int a, std::vector<double> inputVector);

        //handle "find the next node" when the next sibling isn't a function
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
        template<typename T>
        static void staticTemplateTest(T a);



    //handle "find the next node" when the next sibling isn't a function
    private:

        //custom / unknown datatype
        vector3 *returnVector(std::vector<float> &a, vector3 b);

        //const functions
        int cTest(const int a) const;
        int variable_Name2; 

        

    };

#endif
