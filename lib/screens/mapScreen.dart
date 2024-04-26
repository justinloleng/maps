import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';

class mapScreen extends StatefulWidget {
  const mapScreen({super.key});

  @override
  State<mapScreen> createState() => _mapScreenState();
}

class _mapScreenState extends State<mapScreen> {
  static Position? _position;
  late GoogleMapController _mapController;
  var titleController = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  String collectionPath = 'Favorite-Places';
  MapType _currentMapType = MapType.normal;
  var descriptionController = TextEditingController();

  Future<bool> checkServicePermission() async {
    //checking loction services
    bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is Disabled Please Enable it'),
        ),
      );
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is Disabled Please Enable it'),
          ),
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission is permanently denied. Please change in the setting to continue'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> getCurrentLocation() async {
    if (!await checkServicePermission()) {
      return;
    }

    _position = await Geolocator.getCurrentPosition();
    setState(() {
      print("Current Position: $_position");
    });
  }

  void deletePlace(String id) async {
    FirebaseFirestore.instance.collection(collectionPath).doc(id).delete();
    setState(() {});
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCurrentLocation();
  }

  void insertPlace(LatLng pos) async {
    try {
      await FirebaseFirestore.instance.collection(collectionPath).add({
        'markerId': '${pos.latitude + pos.longitude}',
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'title': titleController.text,
        'description': descriptionController.text, 
      }).then((value) => placeMarker(pos));
    } catch (ex) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ex.toString()),
        ),
      );
    }
  }
  void placeMarker(LatLng pos) {
    CameraPosition _cameraPosition = CameraPosition(target: pos, zoom: 15);
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(_cameraPosition),
    );
    titleController.clear();
    setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Scaffold(
        backgroundColor:
            Colors.transparent, 
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/1.png',
                fit: BoxFit.cover,
                width: width,
                height: height,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _position == null
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection(collectionPath)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final snapDoc = snapshot.data?.docs;
                        final List<Marker> _markers = [];
                        if (snapshot.hasData) {
                          final List<DocumentSnapshot> documents =
                              snapshot.data!.docs;
                          for (var document in documents) {
                            final markerId = MarkerId(document.id);
                            final latitude = document['latitude'] as double;
                            final longitude = document['longitude'] as double;
                            final title = document['title'] as String;

                            final marker = Marker(
                              markerId: markerId,
                              position: LatLng(latitude, longitude),
                              infoWindow: InfoWindow(title: title),
                            );
                            _markers.add(marker);
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              child: AnimatedContainer(
                                duration: Duration(seconds: 1),
                                curve: Curves.easeIn,
                                height: height * 0.5,
                                child: GoogleMap(
                                  markers: _markers.toSet(),
                                  mapType: _currentMapType,
                                  myLocationButtonEnabled: true,
                                  myLocationEnabled: true,
                                  initialCameraPosition: CameraPosition(
                                    target: _position != null
                                        ? LatLng(_position!.latitude,
                                            _position!.longitude)
                                        : LatLng(0, 0),
                                    zoom: 10,
                                  ),
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                  },
                                  onTap: (pos) {
                                    QuickAlert.show(
                                      context: context,
                                      type: QuickAlertType.confirm,
                                      text: null,
                                      title:
                                          'Place marker and add to favorite places?',
                                      confirmBtnText: 'Yes',
                                      cancelBtnText: 'No',
                                      onConfirmBtnTap: () {
                                        Navigator.pop(context);
                                        titleModal(context, pos);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                            Center(
                              child: const Text(
                                'Favorite Places',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color.fromARGB(255, 6, 6, 6)),
                              ),
                            ),
                            Container(
                              height: height * 0.3,
                              decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(255, 250, 250, 250)),
                              child: ListView.builder(
                                itemCount: _markers.length,
                                itemBuilder: (context, index) => Card(
                                  child:
                                      favoritesCard(_markers, index, snapDoc),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  Card favoritesCard(List<Marker> _markers, int index,
      List<QueryDocumentSnapshot<Object?>>? snapDoc) {
    return Card(
      child: ListTile(
        onTap: () {
          CameraPosition _cameraPosition =
              CameraPosition(target: _markers[index].position, zoom: 17);
          _mapController.animateCamera(
            CameraUpdate.newCameraPosition(_cameraPosition),
          );
        },
        leading: const Icon(
          Icons.place_outlined,
          color: Colors.red,
        ),
        title: Text(
          '${_markers[index].infoWindow.title}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text('${_markers[index].position}'),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_forever_rounded,
            color: Colors.red,
          ),
          onPressed: () {
            QuickAlert.show(
              context: context,
              type: QuickAlertType.confirm,
              text: null,
              title: 'Are you sure you want to delete this place?',
              confirmBtnText: 'YES',
              cancelBtnText: 'No',
              onConfirmBtnTap: () {
                Navigator.pop(context);
                deletePlace(snapDoc![index].id);
              },
            );
          },
        ),
      ),
    );
  }
  Future<dynamic> titleModal(BuildContext context, LatLng pos) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(12.0),
          child: Form(
            key: _formkey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add a title and description to your favorite place',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    insertPlace(pos);
                    Navigator.pop(context);
                  },
                  child: const Text('Add to Favorites'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
