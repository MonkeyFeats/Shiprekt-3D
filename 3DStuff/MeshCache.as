// Shared static SMesh cache.
//
// This is meant for immutable meshes that can be reused by many Blob3D
// instances. Per-instance position/rotation should stay on Blob3D, while the
// cached SMesh holds only shared geometry/material data.

#include "Camera3D.as"

shared class MeshCacheOptions
{
	bool lighting = false;
	bool zBuffer = true;
	bool zWrite = true;
	bool backFaceCulling = true;
	bool fog = true;
	bool bilinearFilter = false;

	MeshCacheOptions() {}

	MeshCacheOptions(
		const bool _lighting,
		const bool _zBuffer,
		const bool _zWrite,
		const bool _backFaceCulling,
		const bool _fog)
	{
		lighting = _lighting;
		zBuffer = _zBuffer;
		zWrite = _zWrite;
		backFaceCulling = _backFaceCulling;
		fog = _fog;
	}
}

shared class MeshCacheEntry
{
	string key;
	string objPath;
	SMesh@ mesh;
	MeshCacheOptions options;

	MeshCacheEntry() {}

	MeshCacheEntry(const string &in _key, const string &in _objPath, SMesh@ _mesh, const MeshCacheOptions &in _options)
	{
		key = _key;
		objPath = _objPath;
		@mesh = _mesh;
		options = _options;
	}
}

shared class MeshCacheLibrary
{
	private dictionary meshes;
	private string[] keys;

	SMesh@ Get(const string &in key)
	{
		MeshCacheEntry@ entry;
		if (meshes.get(key, @entry) && entry !is null)
		{
			return entry.mesh;
		}

		return null;
	}

	bool Has(const string &in key)
	{
		MeshCacheEntry@ entry;
		return meshes.get(key, @entry) && entry !is null && entry.mesh !is null;
	}

	SMesh@ GetOrLoadObj(const string &in key, const string &in objPath)
	{
		MeshCacheOptions options;
		return GetOrLoadObj(key, objPath, options);
	}

	SMesh@ GetOrLoadObj(const string &in key, const string &in objPath, const MeshCacheOptions &in options)
	{
		SMesh@ cached = Get(key);
		if (cached !is null)
		{
			return cached;
		}

		SMesh@ mesh = BuildObjMesh(objPath, options);
		if (mesh is null)
		{
			warn("MeshCache: failed to build mesh '" + key + "' from '" + objPath + "'");
			return null;
		}

		MeshCacheEntry entry(key, objPath, mesh, options);
		meshes.set(key, @entry);
		keys.push_back(key);
		return mesh;
	}

	bool Register(const string &in key, SMesh@ mesh)
	{
		if (mesh is null)
		{
			warn("MeshCache: ignored null mesh registration for '" + key + "'");
			return false;
		}

		if (!Has(key))
		{
			keys.push_back(key);
		}

		MeshCacheOptions options;
		MeshCacheEntry entry(key, "", mesh, options);
		meshes.set(key, @entry);
		return true;
	}

	void Clear()
	{
		meshes.deleteAll();
		keys.clear();
	}

	uint Count()
	{
		return keys.length();
	}

	string[] GetKeys()
	{
		return keys;
	}

	private SMesh@ BuildObjMesh(const string &in objPath, const MeshCacheOptions &in options)
	{
		SMesh@ mesh = SMesh();
		mesh.LoadObjIntoMesh(objPath);
		mesh.SetHardwareMapping(SMesh::STATIC);

		SMaterial@ material = mesh.GetMaterial();
		if (material !is null)
		{
			material.SetFlag(SMaterial::LIGHTING, options.lighting);
			material.SetFlag(SMaterial::ZBUFFER, options.zBuffer);
			material.SetFlag(SMaterial::ZWRITE_ENABLE, options.zWrite);
			SetMirrorAwareMaterialCulling(material, options.backFaceCulling);
			material.SetFlag(SMaterial::FOG_ENABLE, options.fog);
			material.SetFlag(SMaterial::BILINEAR_FILTER, options.bilinearFilter);
			material.SetLayerBilinearFilter(0, options.bilinearFilter);
		}

		mesh.BuildMesh();
		return mesh;
	}
}

namespace MeshCache
{
	shared string GetRulesKey()
	{
		return "sr3d mesh cache";
	}

	shared MeshCacheLibrary@ GetLibrary()
	{
		CRules@ rules = getRules();
		if (rules is null)
		{
			return null;
		}

		MeshCacheLibrary@ library;
		if (rules.get(GetRulesKey(), @library) && library !is null)
		{
			return library;
		}

		MeshCacheLibrary newLibrary;
		rules.set(GetRulesKey(), @newLibrary);
		rules.get(GetRulesKey(), @library);
		return library;
	}

	shared SMesh@ Get(const string &in key)
	{
		MeshCacheLibrary@ library = GetLibrary();
		return library is null ? null : library.Get(key);
	}

	shared bool Has(const string &in key)
	{
		MeshCacheLibrary@ library = GetLibrary();
		return library !is null && library.Has(key);
	}

	shared SMesh@ GetOrLoadObj(const string &in key, const string &in objPath)
	{
		MeshCacheLibrary@ library = GetLibrary();
		return library is null ? null : library.GetOrLoadObj(key, objPath);
	}

	shared SMesh@ GetOrLoadObj(const string &in key, const string &in objPath, const MeshCacheOptions &in options)
	{
		MeshCacheLibrary@ library = GetLibrary();
		return library is null ? null : library.GetOrLoadObj(key, objPath, options);
	}

	shared bool Register(const string &in key, SMesh@ mesh)
	{
		MeshCacheLibrary@ library = GetLibrary();
		return library !is null && library.Register(key, mesh);
	}

	shared void Clear()
	{
		MeshCacheLibrary@ library = GetLibrary();
		if (library !is null)
		{
			library.Clear();
		}
	}
}
