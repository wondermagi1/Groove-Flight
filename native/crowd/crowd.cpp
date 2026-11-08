// Numerical counterpart of scripts/contact_swarm.gd. No Godot scene/state access.
// Project source. Official Godot interface header retains its own MIT license.
#include "gdextension_interface.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <numeric>
#include <unordered_map>
#include <vector>
#include <limits>

namespace {
struct V {
    float x=0, y=0;
    V operator+(V b) const { return {x+b.x,y+b.y}; }
    V operator-(V b) const { return {x-b.x,y-b.y}; }
    V operator-() const { return {-x,-y}; }
    V operator*(double s) const { return {float(x*s),float(y*s)}; }
    V operator/(double s) const { return {float(x/s),float(y/s)}; }
    float dot(V b) const { return x*b.x+y*b.y; }
    float sq() const { return dot(*this); }
    float length() const { return std::sqrt(sq()); }
};
struct Plane { V normal; float z; };
struct Move { V start,target,wanted,drift; double radius; bool movable,deploying,pressure; int deployment; std::vector<Plane> planes; };
struct Pair { int a,b; };
V closest(V start,V end) {
    V v=end-start; float n=v.sq();
    return n==0 ? start : start+v*std::clamp(-start.dot(v)/n,0.f,1.f);
}
int root(std::vector<int>& parent,int i) {
    int r=i; while(parent[r]!=r) r=parent[r];
    while(parent[i]!=i) { int next=parent[i]; parent[i]=r; i=next; } return r;
}
double safe_fraction(const Move& a,const Move& b) {
    V relative=a.start-b.start, velocity=(a.target-a.start)-(b.target-b.start);
    double minimum=a.radius+b.radius+2;
    if(closest(relative,relative+velocity).sq()>=minimum*minimum-.002) return 1;
    double aa=velocity.sq(); if(aa<.0000001) return 1;
    double bb=2*relative.dot(velocity),cc=std::max(0.,double(relative.sq())-minimum*minimum);
    double disc=bb*bb-4*aa*cc; if(disc<0 || bb>=0) return 1;
    return std::clamp((-bb-std::sqrt(disc))/(2*aa)*.9999,0.,1.);
}
V project(V wanted,const std::vector<Plane>& planes) {
    V result=wanted;
    for(size_t i=0;i<planes.size();++i) {
        const auto& p=planes[i]; V normal=p.normal;
        if(normal.dot(result)>=p.z-.00001) continue;
        V origin=normal*p.z,tangent={normal.y,-normal.x};
        double low=-INFINITY,high=INFINITY;
        for(size_t j=0;j<i;++j) {
            const auto& b=planes[j]; double denominator=b.normal.dot(tangent),numerator=b.z-b.normal.dot(origin);
            if(std::abs(denominator)<.000001) { if(numerator>.0001) return {}; }
            else if(denominator>0) low=std::max(low,numerator/denominator);
            else high=std::min(high,numerator/denominator);
        }
        if(low>high+.0001) return {};
        result=origin+tangent*std::clamp(double(tangent.dot(wanted)),low,high);
    }
    return result;
}
void resolve(std::vector<Move>& m,std::vector<int>& parent,const std::vector<Pair>& pairs,double max_travel) {
    struct Group { V sum,pressure; int count=0,pressers=0; };
    std::vector<Group> groups(m.size()); std::vector<int> roots(m.size());
    for(size_t i=0;i<m.size();++i) {
        roots[i]=root(parent,int(i)); auto& motion=m[i]; motion.planes.clear();
        if(!motion.movable) continue;
        auto& group=groups[roots[i]]; group.sum=group.sum+motion.wanted; ++group.count;
        if(!motion.deploying && motion.pressure) { group.pressure=group.pressure+motion.wanted; ++group.pressers; }
    }
    for(size_t i=0;i<m.size();++i) {
        auto& g=groups[roots[i]]; m[i].drift=g.pressers>0 ? g.pressure/g.pressers : g.sum/std::max(1,g.count);
    }
    for(auto pair:pairs) {
        if(roots[pair.a]!=roots[pair.b]) continue;
        auto& a=m[pair.a]; auto& b=m[pair.b]; V delta=a.start-b.start;
        double distance=delta.length(),margin=std::max(0.,distance-a.radius-b.radius-2.);
        V normal=distance>.0001 ? delta/distance : V{1,0};
        if(a.movable && b.movable) {
            if(margin*.5<=(a.wanted-a.drift).length()+.001) a.planes.push_back({normal,float(-margin*.5)});
            if(margin*.5<=(b.wanted-b.drift).length()+.001) b.planes.push_back({-normal,float(-margin*.5)});
        } else if(a.movable) a.planes.push_back({normal,float((b.wanted-a.drift).dot(normal)-margin)});
        else if(b.movable) b.planes.push_back({-normal,float((a.wanted-b.drift).dot(-normal)-margin)});
    }
    for(auto& motion:m) {
        if(!motion.movable) continue;
        for(int side=0;side<8;++side) {
            double angle=side*6.283185307179586/8.; V normal{float(std::cos(angle)),float(std::sin(angle))};
            motion.planes.push_back({normal,float(-max_travel*1.2-normal.dot(motion.drift))});
        }
        motion.target=motion.start+project(motion.wanted-motion.drift,motion.planes)+motion.drift;
    }
}
int64_t cell(int x,int y) { return int64_t((uint64_t(uint32_t(x))<<32)|uint32_t(y)); }
// Input schema1: [schema,count,max_travel, then10doubles per move].
// startXY,targetXY,radius,movable,deploying,deploymentID,pressure,reserved.
void solve(double* data,int64_t size) {
    if(size<3 || data[0]!=1 || !std::isfinite(data[1]) || data[1]<0 || data[1]>4096) return;
    int n=int(data[1]); if(size!=3+int64_t(n)*10 || !std::isfinite(data[2]) || data[2]<0) return;
    double max_travel=data[2]; std::vector<Move> m; m.reserve(n);
    std::unordered_map<int64_t,std::vector<int>> grid;
    for(int i=0;i<n;++i) {
        const double* r=data+3+i*10;
        for(int j=0;j<10;++j) if(!std::isfinite(r[j])) return;
        Move a; a.start={float(r[0]),float(r[1])}; a.target={float(r[2]),float(r[3])}; a.wanted=a.target-a.start;
        a.radius=r[4]; a.movable=r[5]!=0; a.deploying=r[6]!=0; a.deployment=int(r[7]); a.pressure=r[8]!=0;
        grid[cell(int(std::floor(a.start.x/96.)),int(std::floor(a.start.y/96.)))].push_back(i); m.push_back(a);
    }
    std::vector<int> parent(n); std::iota(parent.begin(),parent.end(),0); std::vector<Pair> pairs;
    double padding=max_travel*2.6+66.;
    for(int i=0;i<n;++i) {
        const auto& a=m[i]; V lo=(a.start-V{float(padding),float(padding)})/96.,hi=(a.start+V{float(padding),float(padding)})/96.;
        for(int x=int(std::floor(lo.x));x<=int(std::floor(hi.x));++x) for(int y=int(std::floor(lo.y));y<=int(std::floor(hi.y));++y) {
            auto found=grid.find(cell(x,y)); if(found==grid.end()) continue;
            for(int j:found->second) {
                if(j<=i) continue; const auto& b=m[j]; if(!a.movable && !b.movable) continue;
                V delta=a.start-b.start; double minimum=a.radius+b.radius+2.;
                if(delta.length()>minimum+max_travel*2.6+.01) continue;
                pairs.push_back({i,j}); if(a.deploying && b.deploying && a.deployment==b.deployment) continue;
                if(closest(delta,delta+a.wanted-b.wanted).length()<minimum+.01) {
                    int ra=root(parent,i),rb=root(parent,j); if(ra!=rb) parent[rb]=ra;
                }
            }
        }
    }
    for(int iteration=0;iteration<16;++iteration) {
        resolve(m,parent,pairs,max_travel); bool merged=false;
        for(auto pair:pairs) {
            if(safe_fraction(m[pair.a],m[pair.b])>=.99999) continue;
            int a=root(parent,pair.a),b=root(parent,pair.b); if(a!=b) { parent[b]=a; merged=true; }
        }
        if(!merged) break;
        if(iteration==15) { std::fill(parent.begin(),parent.end(),0); resolve(m,parent,pairs,max_travel); }
    }
    for(int i=0;i<n;++i) { data[3+i*10+2]=m[i].target.x; data[3+i*10+3]=m[i].target.y; }
}

// Only plain numeric arrays cross the GDExtension boundary. No C++ Godot binding
// dependency or dynamic MSVC runtime is needed. ABI float_64 sizes verified from
// the host executable's --dump-extension-api (Godot4.7.2 Windows64).
struct alignas(8) Name { uint8_t bytes[8]; };
struct alignas(8) Packed { uint8_t bytes[16]; };
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceStringNameNewWithLatin1Chars name_new;
GDExtensionPtrDestructor name_destroy,packed_destroy;
GDExtensionPtrConstructor packed_copy;
GDExtensionPtrBuiltInMethod packed_size;
GDExtensionTypeFromVariantConstructorFunc packed_from_variant;
GDExtensionVariantFromTypeConstructorFunc variant_from_packed;
GDExtensionInterfacePackedFloat64ArrayOperatorIndex packed_index;
GDExtensionInterfaceVariantGetType variant_type;
GDExtensionInterfaceVariantNewNil variant_nil;
GDExtensionInterfaceClassdbRegisterExtensionClass2 register_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
void solve_packed(const void* input,void* output) {
    const void* args[]={input}; packed_copy(output,args);
    int64_t size=0; packed_size(output,nullptr,&size,0);
    if(size>0) solve(packed_index(output,0),size);
}
void call(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr out,GDExtensionCallError* error) {
    if(count!=1 || variant_type(args[0])!=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY) {
        error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; error->argument=0; error->expected=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY; variant_nil(out); return;
    }
    Packed input,output; packed_from_variant(&input,const_cast<void*>(args[0])); solve_packed(&input,&output);
    variant_from_packed(out,&output); packed_destroy(&output); packed_destroy(&input); error->error=GDEXTENSION_CALL_OK;
}
void ptrcall(void*,GDExtensionClassInstancePtr,const GDExtensionConstTypePtr* args,GDExtensionTypePtr out) { solve_packed(args[0],out); }
void initialize(void*,GDExtensionInitializationLevel level) {
    if(level!=GDEXTENSION_INITIALIZATION_SCENE) return;
    Name cls,parent,method,empty,arg; name_new(&cls,"GrooveCrowdKernel",false); name_new(&parent,"RefCounted",false);
    name_new(&method,"solve",false); name_new(&empty,"",false); name_new(&arg,"motions",false);
    GDExtensionClassCreationInfo2 info{}; info.is_abstract=true; info.is_exposed=true; register_class(library,&cls,&parent,&info);
    // Empty String values are required for PropertyInfo even with no hint.
    alignas(8) uint8_t hint[8]{};
    GDExtensionPropertyInfo result{GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,&empty,&empty,0,hint,6};
    GDExtensionPropertyInfo argument{GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,&arg,&empty,0,hint,6};
    GDExtensionClassMethodArgumentMetadata metadata=GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    GDExtensionClassMethodInfo binding{}; binding.name=&method; binding.call_func=call; binding.ptrcall_func=ptrcall;
    binding.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC; binding.has_return_value=true;
    binding.return_value_info=&result; binding.argument_count=1; binding.arguments_info=&argument; binding.arguments_metadata=&metadata;
    register_method(library,&cls,&binding);
    name_destroy(&arg); name_destroy(&empty); name_destroy(&method); name_destroy(&parent); name_destroy(&cls);
}
void deinitialize(void*,GDExtensionInitializationLevel level) {
    if(level==GDEXTENSION_INITIALIZATION_SCENE) { Name cls; name_new(&cls,"GrooveCrowdKernel",false); unregister_class(library,&cls); name_destroy(&cls); }
}
} // namespace

extern "C" __declspec(dllexport) GDExtensionBool groove_crowd_init(GDExtensionInterfaceGetProcAddress get,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init) {
    library=lib;
    name_new=reinterpret_cast<GDExtensionInterfaceStringNameNewWithLatin1Chars>(get("string_name_new_with_latin1_chars"));
    auto destructor=reinterpret_cast<GDExtensionInterfaceVariantGetPtrDestructor>(get("variant_get_ptr_destructor"));
    name_destroy=destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME); packed_destroy=destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);
    auto constructor=reinterpret_cast<GDExtensionInterfaceVariantGetPtrConstructor>(get("variant_get_ptr_constructor"));
    packed_copy=constructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,1);
    auto builtin=reinterpret_cast<GDExtensionInterfaceVariantGetPtrBuiltinMethod>(get("variant_get_ptr_builtin_method"));
    Name size; name_new(&size,"size",false); packed_size=builtin(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,&size,3173160232); name_destroy(&size);
    auto to_type=reinterpret_cast<GDExtensionInterfaceGetVariantToTypeConstructor>(get("get_variant_to_type_constructor"));
    auto from_type=reinterpret_cast<GDExtensionInterfaceGetVariantFromTypeConstructor>(get("get_variant_from_type_constructor"));
    packed_from_variant=to_type(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY); variant_from_packed=from_type(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);
    packed_index=reinterpret_cast<GDExtensionInterfacePackedFloat64ArrayOperatorIndex>(get("packed_float64_array_operator_index"));
    variant_type=reinterpret_cast<GDExtensionInterfaceVariantGetType>(get("variant_get_type"));
    variant_nil=reinterpret_cast<GDExtensionInterfaceVariantNewNil>(get("variant_new_nil"));
    register_class=reinterpret_cast<GDExtensionInterfaceClassdbRegisterExtensionClass2>(get("classdb_register_extension_class2"));
    register_method=reinterpret_cast<GDExtensionInterfaceClassdbRegisterExtensionClassMethod>(get("classdb_register_extension_class_method"));
    unregister_class=reinterpret_cast<GDExtensionInterfaceClassdbUnregisterExtensionClass>(get("classdb_unregister_extension_class"));
    init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE; init->initialize=initialize; init->deinitialize=deinitialize; init->userdata=nullptr;
    return packed_size && packed_copy && packed_index;
}
