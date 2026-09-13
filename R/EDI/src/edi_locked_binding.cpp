#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
void edi_unlock_binding_cpp(std::string name, Environment env){
	R_unLockBinding(Rf_install(name.c_str()), env);
}
