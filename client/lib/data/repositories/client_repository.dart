import '../models/client_model.dart';

abstract class ClientRepository {
  Future<List<Client>> getClients({String? query});
  Future<void> addClient(Client client);
}
